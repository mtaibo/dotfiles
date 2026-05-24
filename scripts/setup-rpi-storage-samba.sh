#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; NC='\033[0m'
log()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

MOUNT_POINT="/mnt/storage"
SMB_CONF="/etc/samba/smb.conf"

# ------------------------------------------------------------------
# Require root
# ------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  err "This script must be run as root (sudo)"
  exit 1
fi

# ------------------------------------------------------------------
# Detect USB disk
# ------------------------------------------------------------------
detect_disk() {
  if [ -n "${1:-}" ]; then
    DEVICE="$1"
    if [ ! -b "$DEVICE" ]; then
      err "Device $DEVICE does not exist or is not a block device"
      exit 1
    fi
    ok "Using specified device: $DEVICE"
    return
  fi

  log "Auto-detecting USB disk..."
  ROOT_DEV=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')

  CANDIDATES=$(lsblk -d -n -o NAME,SIZE,TYPE | awk '$3 == "disk" && $1 != "'"$(basename "$ROOT_DEV")"'" && $1 !~ /^zram/ {print "/dev/" $1, $2}')

  if [ -z "$CANDIDATES" ]; then
    err "No USB disk detected. Specify it manually:"
    echo "  sudo $0 /dev/sdX"
    echo ""
    echo "Available disks:"
    lsblk -d -n -o NAME,SIZE,TYPE
    exit 1
  fi

  COUNT=$(echo "$CANDIDATES" | wc -l)
  if [ "$COUNT" -gt 1 ]; then
    warn "Multiple disks found, picking the largest:"
    echo "$CANDIDATES" | while read -r dev size; do
      echo "  $dev ($size)"
    done
    DEVICE=$(echo "$CANDIDATES" | sort -k2 -h | tail -1 | awk '{print $1}')
  else
    DEVICE=$(echo "$CANDIDATES" | awk '{print $1}')
  fi
  ok "Detected disk: $DEVICE"
}

# ------------------------------------------------------------------
# Detect partition and filesystem
# ------------------------------------------------------------------
detect_partition() {
  PARTITIONS=$(lsblk -l -n -o NAME,SIZE,TYPE "$DEVICE" | awk '$3 == "part" {print "/dev/" $1, $2}')

  if [ -z "$PARTITIONS" ]; then
    warn "No partition found on $DEVICE, falling back to /dev/disk/by-id"
    PARTITION=$(ls -1 /dev/disk/by-id/ 2>/dev/null | grep -v part | grep "$(basename "$DEVICE")" | head -1)
    if [ -n "$PARTITION" ]; then
      PARTITION="/dev/disk/by-id/$PARTITION"
    else
      PARTITION="$DEVICE"
    fi
  else
    PARTITION=$(echo "$PARTITIONS" | sort -k2 -h | tail -1 | awk '{print $1}')
  fi

  if ! blkid "$PARTITION" &>/dev/null; then
    err "Cannot read filesystem on $PARTITION"
    echo "  Make sure the disk has a partition with a filesystem."
    echo "  Available partitions:"
    lsblk -l -n -o NAME,SIZE,TYPE,FSTYPE "$DEVICE" 2>/dev/null || true
    exit 1
  fi

  FS_TYPE=$(blkid -s TYPE -o value "$PARTITION")
  ok "Partition: $PARTITION (filesystem: $FS_TYPE)"
}

# ------------------------------------------------------------------
# Mount disk
# ------------------------------------------------------------------
mount_disk() {
  log "Creating mount point: $MOUNT_POINT"
  mkdir -p "$MOUNT_POINT"

  if mountpoint -q "$MOUNT_POINT"; then
    warn "$MOUNT_POINT is already mounted, unmounting first..."
    umount "$MOUNT_POINT" 2>/dev/null || umount -l "$MOUNT_POINT" 2>/dev/null || true
  fi

  log "Mounting $PARTITION -> $MOUNT_POINT"

  MOUNT_OPTS=""
  case "$FS_TYPE" in
    vfat|fat32)
      MOUNT_OPTS="uid=1000,gid=1000,dmask=022,fmask=133"
      ;;
    exfat)
      MOUNT_OPTS="uid=1000,gid=1000,dmask=022,fmask=133"
      ;;
    ntfs|ntfs3)
      MOUNT_OPTS="uid=1000,gid=1000,dmask=022,fmask=133"
      ;;
  esac

  if [ -n "$MOUNT_OPTS" ]; then
    mount -o "$MOUNT_OPTS" "$PARTITION" "$MOUNT_POINT"
  else
    mount "$PARTITION" "$MOUNT_POINT"
  fi
  ok "Disk mounted at $MOUNT_POINT"
}

# ------------------------------------------------------------------
# Add to fstab
# ------------------------------------------------------------------
setup_fstab() {
  UUID=$(blkid -s UUID -o value "$PARTITION")

  # Remove any existing entries for this mount point or UUID
  if grep -q "$MOUNT_POINT\|$UUID" /etc/fstab 2>/dev/null; then
    log "Cleaning stale fstab entries"
    sed -i "\|$MOUNT_POINT|d" /etc/fstab
    sed -i "\|$UUID|d" /etc/fstab
  fi

  log "Adding fstab entry (UUID=$UUID)"

  MOUNT_OPTS="defaults"
  case "$FS_TYPE" in
    vfat|fat32|exfat|ntfs|ntfs3)
      MOUNT_OPTS="defaults,uid=1000,gid=1000,dmask=022,fmask=133"
      ;;
  esac

  echo "UUID=$UUID  $MOUNT_POINT  $FS_TYPE  $MOUNT_OPTS  0  2" >> /etc/fstab
  ok "fstab entry added"
}

# ------------------------------------------------------------------
# Create expected system users (if they don't exist)
# ------------------------------------------------------------------
setup_system_users() {
  local DEFAULT_PASSWORD="1234"

  for username in ricardo pablo casa; do
    if id "$username" &>/dev/null; then
      warn "User '$username' already exists, skipping"
    else
      log "Creating system user: $username"
      useradd \
        --create-home \
        --shell /bin/bash \
        --comment "$username" \
        "$username"
      echo "${username}:${DEFAULT_PASSWORD}" | chpasswd
      ok "User '$username' created with password set"
    fi
  done
}

# ------------------------------------------------------------------
# Install samba
# ------------------------------------------------------------------
install_samba() {
  if command -v smbd &>/dev/null; then
    ok "Samba is already installed"
    return
  fi

  log "Installing samba..."
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq samba ufw
  ok "Samba installed"
}

# ------------------------------------------------------------------
# Detect system users (UID >= 1000, non-system)
# ------------------------------------------------------------------
detect_users() {
  USERS=()
  while IFS=: read -r username _ uid _ _ home _; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ]; then
      # Skip system and build users
      if [[ "$username" != nixbld* ]] && \
         [ "$username" != "nobody" ] && \
         [ "$username" != "nogroup" ]; then
        USERS+=("$username")
      fi
    fi
  done < /etc/passwd

  if [ ${#USERS[@]} -eq 0 ]; then
    err "No system users found (UID >= 1000)"
    exit 1
  fi

  log "Found ${#USERS[@]} user(s): ${USERS[*]}"
}

# ------------------------------------------------------------------
# Setup user directories and Samba credentials
# ------------------------------------------------------------------
setup_users() {
  for username in "${USERS[@]}"; do
    user_dir="${MOUNT_POINT}/${username}"

    # Create directory
    if [ ! -d "$user_dir" ]; then
      log "Creating directory: $user_dir"
      mkdir -p "$user_dir"
    else
      warn "Directory already exists: $user_dir (preserving content)"
    fi

    # Set permissions (only on native Linux filesystems)
    case "$FS_TYPE" in
      vfat|fat32|exfat|ntfs|ntfs3)
        warn "Filesystem $FS_TYPE doesn't support Unix permissions — ownership set via mount options"
        ;;
      *)
        chmod 700 "$user_dir"
        chown "${username}:${username}" "$user_dir"
        ok "Permissions set for $username"
        ;;
    esac

    # Set Samba password
    if pdbedit -L 2>/dev/null | grep -q "^${username}:"; then
      warn "Samba user '$username' already exists, updating password..."
    else
      log "Creating Samba user: $username"
    fi

    echo -e "${YELLOW}Enter Samba password for '$username':${NC} "
    read -rs password
    echo ""
    read -rs password_confirm
    echo ""

    if [ "$password" != "$password_confirm" ]; then
      err "Passwords do not match for user '$username'"
      exit 1
    fi

    echo -e "${password}\n${password}" | smbpasswd -s -a "$username"
    ok "Samba credentials set for '$username'"
  done
}

# ------------------------------------------------------------------
# Generate smb.conf
# ------------------------------------------------------------------
generate_smb_conf() {
  log "Generating $SMB_CONF..."

  # Build valid users list
  VALID_USERS=""
  for username in "${USERS[@]}"; do
    if [ -n "$VALID_USERS" ]; then
      VALID_USERS="${VALID_USERS}, ${username}"
    else
      VALID_USERS="$username"
    fi
  done

  cat > "$SMB_CONF" << GLOBAL_EOF
[global]
  workgroup = WORKGROUP
  server string = tphome Samba Server
  security = user
  map to guest = never
  log file = /var/log/samba/log.%m
  max log size = 1000
  dns proxy = no

  # macOS compatibility (resource forks, metadata)
  vfs objects = fruit streams_xattr
  fruit:model = MacSamba
  fruit:aapl = yes

[storage]
  path = ${MOUNT_POINT}/%U
  browseable = yes
  read only = no
  writable = yes
  guest ok = no
  valid users = ${VALID_USERS}
  create mask = 0600
  directory mask = 0700
  # macOS compatibility
  fruit:aapl = yes
GLOBAL_EOF

  ok "smb.conf generated (single share, auto-resolves to user folder)"
}

# ------------------------------------------------------------------
# Firewall
# ------------------------------------------------------------------
setup_firewall() {
  log "Configuring firewall..."
  ufw allow 139/tcp 2>/dev/null || true
  ufw allow 445/tcp 2>/dev/null || true
  ufw allow 137/udp 2>/dev/null || true
  ufw allow 138/udp 2>/dev/null || true
  ok "Firewall rules added (ports 139, 445, 137, 138)"
}

# ------------------------------------------------------------------
# Start services
# ------------------------------------------------------------------
start_services() {
  log "Starting Samba services..."
  systemctl enable smbd nmbd
  systemctl restart smbd nmbd
  ok "Samba services started and enabled"
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RPi Storage + Samba Setup (tphome)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Storage setup
detect_disk "${1:-}"
detect_partition

# Clean stale fstab entries for this mount point before adding new one
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
  umount "$MOUNT_POINT" 2>/dev/null || umount -l "$MOUNT_POINT" 2>/dev/null || true
fi

mount_disk
setup_fstab

# Samba setup
install_samba
setup_system_users
detect_users
setup_users
generate_smb_conf
setup_firewall
start_services

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Done!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  Storage mounted at: $MOUNT_POINT"
echo "  User folders:"
for username in "${USERS[@]}"; do
  echo "    /mnt/storage/$username"
done
echo ""
echo "  Connect to: smb://tphome.local/storage"
echo "  Each user lands directly in their own folder"
echo ""
echo "  From macOS (Finder → Cmd+K):"
echo "    smb://tphome.local/storage"
echo ""
echo "  From Linux:"
echo "    smb://tphome.local/storage"
echo ""
