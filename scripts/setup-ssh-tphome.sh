#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[*]${NC} $1"; }
ok()  { echo -e "${GREEN}[✓]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }

KEY_PATH="$HOME/.ssh/tphome"
TAG="tphome-$(hostname)"
SSH_CONFIG="$HOME/.ssh/config"
HOST="tphome"
ADDR="192.168.1.160"
USER="migueltaibo"

# ------------------------------------------------------------------
log "Checking gh authentication..."
# ------------------------------------------------------------------
if ! gh auth status &>/dev/null; then
  err "gh not authenticated. Run: gh auth login"
  exit 1
fi
ok "gh authenticated"

# ------------------------------------------------------------------
log "Generating SSH key pair..."
# ------------------------------------------------------------------
if [ ! -f "$KEY_PATH" ]; then
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "$TAG" -q
  ok "Key generated: $KEY_PATH"
else
  ok "Key already exists: $KEY_PATH"
fi

# ------------------------------------------------------------------
log "Uploading public key to GitHub..."
# ------------------------------------------------------------------
if ! gh ssh-key list &>/dev/null; then
  err "gh token missing 'admin:public_key' scope."
  err "Run: gh auth refresh -h github.com -s admin:public_key"
  exit 1
fi
if gh ssh-key list 2>/dev/null | grep -qi "$TAG"; then
  ok "Key '$TAG' already on GitHub"
else
  gh ssh-key add "$KEY_PATH.pub" --title "$TAG"
  ok "Public key uploaded to GitHub as '$TAG'"
fi

# ------------------------------------------------------------------
log "Writing tphome host to ~/.ssh/config..."
# ------------------------------------------------------------------
mkdir -p "$(dirname "$SSH_CONFIG")"
touch "$SSH_CONFIG"
# Remove old Host tphome block if any
awk '/^Host /{found=0} /^Host tphome(\b|$)/{found=1; next} !found' "$SSH_CONFIG" > "$SSH_CONFIG.tmp"
mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"

cat >> "$SSH_CONFIG" <<EOF

Host $HOST
  HostName $ADDR
  User $USER
  IdentityFile $KEY_PATH
EOF
ok "Host $HOST configured in $SSH_CONFIG"

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "  Try it: ssh $HOST"
echo "  Then on RPi run: update"
echo ""
