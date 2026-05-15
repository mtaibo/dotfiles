#!/usr/bin/env bash
set -euo pipefail

TPHOME_DIR="$HOME/tphome"
TPHOME_API_DIR="$HOME/tphome-api"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${BLUE}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

check_repos() {
  local missing=0
  for d in "$TPHOME_DIR" "$TPHOME_API_DIR"; do
    if [ ! -d "$d" ]; then
      err "Repo not found: $d"
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    echo ""
    warn "Clone them first:"
    echo "  git clone git@github.com:mtaibo/tphome.git     $TPHOME_DIR"
    echo "  git clone git@github.com:mtaibo/tphome-api.git $TPHOME_API_DIR"
    exit 1
  fi
}

cmd_up() {
  check_repos
  log "Creating shared network (if needed)..."
  docker network create tphome-network 2>/dev/null || true
  log "Starting tphome-api (mosquitto + fastapi)..."
  (cd "$TPHOME_API_DIR" && docker-compose up --build -d)
  log "Starting tphome (frontend + caddy)..."
  (cd "$TPHOME_DIR" && docker-compose up --build -d)
  echo ""
  ok "Both stacks are up!"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

cmd_down() {
  check_repos
  log "Stopping tphome..."
  (cd "$TPHOME_DIR" && docker-compose down) 2>/dev/null || true
  log "Stopping tphome-api..."
  (cd "$TPHOME_API_DIR" && docker-compose down) 2>/dev/null || true
  ok "Both stacks are down."
}

cmd_logs() {
  check_repos
  if [ $# -eq 0 ]; then
    (cd "$TPHOME_DIR" && docker-compose logs --tail=20 -f) &
    (cd "$TPHOME_API_DIR" && docker-compose logs --tail=20 -f) &
    wait
  else
    case "$1" in
      frontend|caddy) (cd "$TPHOME_DIR" && docker-compose logs --tail=50 -f "$1") ;;
      api|mosquitto)  (cd "$TPHOME_API_DIR" && docker-compose logs --tail=50 -f "$1") ;;
      *)              err "Unknown service: $1"; usage ;;
    esac
  fi
}

cmd_ps() {
  check_repos
  echo -e "${BLUE}tphome:${NC}"
  (cd "$TPHOME_DIR" && docker-compose ps)
  echo ""
  echo -e "${BLUE}tphome-api:${NC}"
  (cd "$TPHOME_API_DIR" && docker-compose ps)
}

cmd_rebuild() {
  cmd_down
  cmd_up
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  up         Build and start all services
  down       Stop all services
  logs [svc] Follow logs (svc: frontend|caddy|api|mosquitto)
  ps         Show container status
  rebuild    Down then up (full restart)

EOF
  exit 1
}

case "${1:-}" in
  up)      shift; cmd_up "$@" ;;
  down)    shift; cmd_down "$@" ;;
  logs)    shift; cmd_logs "$@" ;;
  ps)      shift; cmd_ps "$@" ;;
  rebuild) shift; cmd_rebuild "$@" ;;
  *)       usage ;;
esac
