#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[*]${NC} $1"; }
ok()  { echo -e "${GREEN}[✓]${NC} $1"; }

HOSTNAME="tphome"
REPO="https://github.com/mtaibo/dotfiles"
FLAKE_PATH="$HOME/Dotfiles"

# ------------------------------------------------------------------
log "Setting hostname to $HOSTNAME..."
# ------------------------------------------------------------------
sudo hostnamectl set-hostname "$HOSTNAME"
if grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
  sudo sed -i "s/^127\.[0-9]\+\.[0-9]\+\.[0-9]\+[[:space:]]\+.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
else
  echo "127.0.1.1\t$HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
fi
ok "Hostname set to $HOSTNAME"

# ------------------------------------------------------------------
log "Installing Nix (Determinate Systems)..."
# ------------------------------------------------------------------
if ! command -v nix &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -fsSL https://install.determinate.systems/nix | sh -s -- install
  ok "Nix installed"
else
  ok "Nix already installed"
fi

export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

mkdir -p ~/.config/nix
if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  ok "Flakes enabled"
fi

# ------------------------------------------------------------------
log "Cloning dotfiles repo..."
# ------------------------------------------------------------------
if [ ! -d "$FLAKE_PATH" ]; then
  mkdir -p "$FLAKE_PATH"
  curl -fsSL "$REPO/archive/main.tar.gz" | tar xz -C "$FLAKE_PATH" --strip-components=1
  ok "Repo cloned to $FLAKE_PATH"
else
  ok "Repo already exists at $FLAKE_PATH"
fi

# ------------------------------------------------------------------
log "Installing Docker..."
# ------------------------------------------------------------------
sudo apt update -qq
sudo apt install -y -qq docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
ok "Docker installed and enabled"

# ------------------------------------------------------------------
log "Installing Tailscale..."
# ------------------------------------------------------------------
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
ok "Tailscale installed"

# ------------------------------------------------------------------
log "Deploying home-manager config (first run with nix run)..."
# ------------------------------------------------------------------
nix run github:nix-community/home-manager -- switch --flake "$FLAKE_PATH#tphome"
ok "Config deployed"

echo ""
echo -e "${GREEN}RPi setup complete!${NC}"
echo ""
echo "  Next steps:"
echo "    1. Log out and back in for docker group to take effect"
echo "    2. Run: tailscale up"
echo "    3. Run: dotfiles          (or just open a new terminal)"
echo ""
