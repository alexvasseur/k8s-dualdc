#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-status}"

log() {
  printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd kubectl

get_dc1_nodes() {
  kubectl get nodes -l dc=dc1 -o name 2>/dev/null || true
}

get_dc1_nodes_fallback() {
  kubectl get nodes -l topology.kubernetes.io/zone=dc1 -o name 2>/dev/null || true
}

get_nodes() {
  local nodes
  nodes="$(get_dc1_nodes)"
  if [[ -z "${nodes}" ]]; then
    nodes="$(get_dc1_nodes_fallback)"
  fi
  printf '%s\n' "${nodes}" | sed '/^$/d'
}

is_control_plane() {
  local node="$1"
  kubectl get "${node}" -o jsonpath='{.metadata.labels.node-role\.kubernetes\.io/control-plane}' 2>/dev/null | grep -q '^'
}

show_status() {
  log "DC1 nodes:"
  get_nodes | while read -r node; do
    [[ -z "${node}" ]] && continue
    local name unsched zone dc roles
    name="${node#node/}"
    unsched="$(kubectl get "${node}" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)"
    zone="$(kubectl get "${node}" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}' 2>/dev/null || true)"
    dc="$(kubectl get "${node}" -o jsonpath='{.metadata.labels.dc}' 2>/dev/null || true)"
    roles="$(kubectl get "${node}" -o jsonpath='{.metadata.labels}' | grep -o 'node-role.kubernetes.io/[^"]*' | paste -sd ',' - || true)"
    printf '  - %s  dc=%s zone=%s unschedulable=%s roles=%s\n' \
      "${name}" "${dc:-?}" "${zone:-?}" "${unsched:-false}" "${roles:-unknown}"
  done

  echo
  log "Non-terminated pods still running on DC1-like nodes:"
  kubectl get pods -A -o wide --field-selector=status.phase!=Succeeded,status.phase!=Failed | \
    awk 'NR==1 || $8 ~ /dc1/'
}

fail_dc1() {
  local drain_control_plane="${1:-false}"
  local found=0

  while read -r node; do
    [[ -z "${node}" ]] && continue
    found=1
    local name
    name="${node#node/}"

    log "Cordoning ${name}"
    kubectl cordon "${name}"

    if is_control_plane "${node}"; then
      if [[ "${drain_control_plane}" == "true" ]]; then
        log "Draining control-plane node ${name}"
        kubectl drain "${name}" \
          --ignore-daemonsets \
          --delete-emptydir-data \
          --force \
          --grace-period=30 \
          --timeout=120s || true
      else
        log "Skipping drain on control-plane node ${name} (cordon only)"
      fi
    else
      log "Draining worker node ${name}"
      kubectl drain "${name}" \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --force \
        --grace-period=30 \
        --timeout=120s || true
    fi
  done < <(get_nodes)

  if [[ "${found}" -eq 0 ]]; then
    log "No DC1 nodes found. Expected label dc=dc1 or topology.kubernetes.io/zone=dc1."
    exit 1
  fi

  echo
  log "Pods after DC1 failure simulation:"
  kubectl get pods -A -o wide
}

restore_dc1() {
  local found=0

  while read -r node; do
    [[ -z "${node}" ]] && continue
    found=1
    local name
    name="${node#node/}"
    log "Uncordoning ${name}"
    kubectl uncordon "${name}"
  done < <(get_nodes)

  if [[ "${found}" -eq 0 ]]; then
    log "No DC1 nodes found. Expected label dc=dc1 or topology.kubernetes.io/zone=dc1."
    exit 1
  fi

  echo
  log "Cluster nodes after restore:"
  kubectl get nodes
}

case "${MODE}" in
  fail)
    log "Simulating DC1 failure: cordon all DC1 nodes, drain DC1 workers"
    fail_dc1 false
    ;;
  fail-hard)
    log "Simulating hard DC1 failure: cordon and drain all DC1 nodes including control-plane"
    fail_dc1 true
    ;;
  restore)
    log "Restoring DC1 nodes"
    restore_dc1
    ;;
  status)
    show_status
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    echo "Usage: $0 {fail|fail-hard|restore|status}" >&2
    exit 1
    ;;
esac
