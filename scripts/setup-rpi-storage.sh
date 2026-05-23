#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; NC='\033[0m'
log()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

MOUNT_POINT="/mnt/storage"
RICARDO_DIR="${MOUNT_POINT}/Ricardo"
USERNAME="ricardo"
PASSWORD="1234"

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

  CANDIDATES=$(lsblk -d -n -o NAME,SIZE,TYPE | awk '$3 == "disk" && $1 != "'"$(basename "$ROOT_DEV")"'" {print "/dev/" $1, $2}')

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
  PARTITION=$(lsblk -n -o NAME,TYPE "$DEVICE" | awk '$2 == "part" {print "/dev/" $1; exit}')

  if [ -z "$PARTITION" ]; then
    warn "No partition found on $DEVICE, using whole disk"
    PARTITION="$DEVICE"
  fi

  if ! blkid "$PARTITION" &>/dev/null; then
    err "Cannot read filesystem on $PARTITION"
    echo "  Make sure the disk has a partition with a filesystem."
    echo "  To format as ext4: sudo mkfs.ext4 ${PARTITION}1"
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
    umount "$MOUNT_POINT"
  fi

  log "Mounting $PARTITION -> $MOUNT_POINT"
  mount "$PARTITION" "$MOUNT_POINT"
  ok "Disk mounted at $MOUNT_POINT"
}

# ------------------------------------------------------------------
# Add to fstab
# ------------------------------------------------------------------
setup_fstab() {
  UUID=$(blkid -s UUID -o value "$PARTITION")

  if grep -q "$UUID" /etc/fstab 2>/dev/null; then
    ok "fstab entry already exists for UUID=$UUID"
    return
  fi

  log "Adding fstab entry (UUID=$UUID)"

  MOUNT_OPTS="defaults"
  if [ "$FS_TYPE" = "ntfs" ] || [ "$FS_TYPE" = "ntfs3" ]; then
    MOUNT_OPTS="defaults,uid=1000,gid=1000,dmask=022,fmask=133"
  elif [ "$FS_TYPE" = "exfat" ]; then
    MOUNT_OPTS="defaults,uid=1000,gid=1000,dmask=022,fmask=133"
  fi

  echo "UUID=$UUID  $MOUNT_POINT  $FS_TYPE  $MOUNT_OPTS  0  2" >> /etc/fstab
  ok "fstab entry added"
}

# ------------------------------------------------------------------
# Create ricardo user
# ------------------------------------------------------------------
setup_user() {
  if [ ! -d "$RICARDO_DIR" ]; then
    log "Creating $RICARDO_DIR"
    mkdir -p "$RICARDO_DIR"
  else
    warn "$RICARDO_DIR already exists, preserving content"
  fi

  if id "$USERNAME" &>/dev/null; then
    warn "User '$USERNAME' already exists, updating home directory..."
    usermod -d "$RICARDO_DIR" "$USERNAME" 2>/dev/null || true
  else
    log "Creating user '$USERNAME' with home=$RICARDO_DIR"
    useradd \
      --home-dir "$RICARDO_DIR" \
      --create-home \
      --shell /bin/bash \
      --comment "Ricardo" \
      "$USERNAME"
  fi

  echo "${USERNAME}:${PASSWORD}" | chpasswd
  ok "User '$USERNAME' configured with password set"

  log "Setting directory permissions"
  chmod 755 "$MOUNT_POINT"
  chmod 700 "$RICARDO_DIR"
  chown "${USERNAME}:${USERNAME}" "$RICARDO_DIR"
  ok "Permissions set — only $USERNAME can access $RICARDO_DIR"
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RPi Storage & User Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

detect_disk "${1:-}"
detect_partition
mount_disk
setup_fstab
setup_user

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Done!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  Storage mounted at: $MOUNT_POINT"
echo "  User: $USERNAME"
echo "  Home: $RICARDO_DIR"
echo "  Password: $PASSWORD"
echo ""
echo "  Test login: ssh $USERNAME@$(hostname -I | awk '{print $1}')"
echo ""
