#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-status}"
CLUSTER_NAME="${CLUSTER_NAME:-c1}"

log() {
  printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd docker
require_cmd kubectl

get_dc2_nodes() {
  kubectl get nodes -l dc=dc2 -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true
}

get_containers() {
  local nodes
  nodes="$(get_dc2_nodes)"
  for n in ${nodes}; do
    printf '%s\n' "${n}"
  done
}

pause_nodes() {
  for c in $(get_containers); do
    log "Pausing container ${c}"
    docker pause "${c}" || true
  done
}

stop_nodes() {
  for c in $(get_containers); do
    log "Stopping container ${c}"
    docker stop "${c}" || true
  done
}

restore_nodes() {
  for c in $(get_containers); do
    if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
      if docker inspect -f '{{.State.Paused}}' "${c}" 2>/dev/null | grep -q true; then
        log "Unpausing ${c}"
        docker unpause "${c}" || true
      fi
      if docker inspect -f '{{.State.Running}}' "${c}" 2>/dev/null | grep -q false; then
        log "Starting ${c}"
        docker start "${c}" || true
      fi
    fi
  done
}

status() {
  log "Docker container status (DC2 nodes):"
  for c in $(get_containers); do
    docker ps -a --filter "name=${c}" --format "table {{.Names}}\t{{.Status}}"
  done

  echo
  log "Kubernetes node status:"
  kubectl get nodes -o wide

  echo
  log "Pods distribution:"
  kubectl get pods -A -o wide
}

case "${MODE}" in
  pause)
    log "Simulating DC2 network freeze (docker pause)"
    pause_nodes
    ;;
  stop)
    log "Simulating DC2 power loss (docker stop)"
    stop_nodes
    ;;
  restore)
    log "Restoring DC2 nodes"
    restore_nodes
    ;;
  status)
    status
    ;;
  *)
    echo "Usage: $0 {pause|stop|restore|status}"
    exit 1
    ;;
esac
