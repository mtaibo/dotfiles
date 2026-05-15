#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[*]${NC} $1"; }
ok()  { echo -e "${GREEN}[✓]${NC} $1"; }

HOSTNAME="tphome"
REPO="https://github.com/mtaibo/dotfiles"
FLAKE_PATH="$HOME/dotfiles"

# Ensure Nix is in PATH (works whether fresh install or existing)
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

# ------------------------------------------------------------------
log "Setting hostname to $HOSTNAME..."
# ------------------------------------------------------------------
sudo hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || true
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
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  ok "Nix installed"
else
  ok "Nix already installed"
fi

mkdir -p ~/.config/nix
if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  ok "Flakes enabled"
fi

# ------------------------------------------------------------------
log "Cloning dotfiles repo (curl tarball, git not available yet)..."
# ------------------------------------------------------------------
cd /tmp
rm -rf "$FLAKE_PATH"
mkdir -p "$FLAKE_PATH"
curl -fsSL "$REPO/archive/main.tar.gz" | tar xz -C "$FLAKE_PATH" --strip-components=1
ok "Repo fetched to $FLAKE_PATH (no .git yet)"

# ------------------------------------------------------------------
log "Cleaning previous home-manager profile (if any)..."
# ------------------------------------------------------------------
if nix profile list 2>/dev/null | grep -qi home-manager; then
  nix profile remove home-manager 2>/dev/null || true
  ok "Removed conflicting home-manager from nix profile"
else
  ok "No conflict found"
fi

# ------------------------------------------------------------------
log "Installing Docker..."
# ------------------------------------------------------------------
sudo apt update -qq
sudo apt install -y -qq docker.io docker-compose-v2
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
log "Suppressing Debian MOTD..."
# ------------------------------------------------------------------
echo "PrintMotd no" | sudo tee /etc/ssh/sshd_config.d/99-no-motd.conf >/dev/null
sudo truncate -s 0 /etc/motd 2>/dev/null || true
sudo systemctl restart sshd
ok "MOTD suppressed"

# ------------------------------------------------------------------
log "Deploying home-manager config..."
# ------------------------------------------------------------------
nix run github:nix-community/home-manager -- switch --flake "$FLAKE_PATH#tphome"
ok "Config deployed"

# ------------------------------------------------------------------
log "Re-cloning with git (so repo has .git history)..."
# ------------------------------------------------------------------
cd /tmp
rm -rf "$FLAKE_PATH"
git clone "$REPO" "$FLAKE_PATH"
ok "Repo now has .git — you can git pull"

# ------------------------------------------------------------------
log "Setting default shell to zsh..."
# ------------------------------------------------------------------
ZSH_PATH="$(which zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  sudo chsh -s "$ZSH_PATH" "$USER"
  ok "Default shell changed to zsh (log out and back in)"
else
  ok "zsh is already the default shell"
fi

# ------------------------------------------------------------------
log "Authenticating with GitHub..."
# ------------------------------------------------------------------
gh auth login
ok "GitHub authenticated"

echo ""
echo -e "${GREEN}RPi setup complete!${NC}"
echo ""
echo "  Next steps:"
echo "    1. Log out and back in for docker group + zsh to take effect"
echo "    2. Run: tailscale up"
echo "    3. Then, just run: update"
echo ""
