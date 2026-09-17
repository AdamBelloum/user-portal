#!/usr/bin/env bash
# Read-only Kubernetes readiness checks for the DIGITAfrica user portal.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/admin/healthcheck.sh [all|infrastructure|keycloak|database]

Scopes:
  all             Run every read-only portal readiness check. Default.
  infrastructure  Check the namespace and all portal workload pod states.
  keycloak        Check the Keycloak deployment rollout and service.
  database        Check the PostgreSQL StatefulSet rollout and service.
  cache           Check the Redis StatefulSet rollout and service.
  help            Show this help text.

This command does not alter Kubernetes resources. OIDC realm/client login
validation is added after automated realm and client provisioning exists.
USAGE
}

run_remote_check() {
  local title="$1"
  local remote_script="$2"

  heading "${title}"
  remote_script="${remote_script//__USER_PORTAL_NAMESPACE__/${USER_PORTAL_NAMESPACE}}"
  run_target_remote "${remote_script}"
}

check_infrastructure() {
  run_remote_check \
    "Portal infrastructure health" \
    "$(cat <<'REMOTE_SCRIPT'
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

printf '%s\n' '===== Namespace ====='
k3s kubectl get namespace __USER_PORTAL_NAMESPACE__

printf '%s\n' '===== Portal workloads ====='
k3s kubectl -n __USER_PORTAL_NAMESPACE__ get deployments,statefulsets,pods -o wide

if ! k3s kubectl -n __USER_PORTAL_NAMESPACE__ get pods --no-headers \
  | awk '$3 ~ /^(Running|Completed)$/ { next } { exit 1 }'; then
  echo 'ERROR: one or more portal pods are not Running or Completed.' >&2
  exit 1
fi

echo 'Portal infrastructure health check passed.'
REMOTE_SCRIPT
)"
}

check_keycloak() {
  run_remote_check \
    "Keycloak health" \
    "$(cat <<'REMOTE_SCRIPT'
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

printf '%s\n' '===== Keycloak rollout ====='
k3s kubectl -n __USER_PORTAL_NAMESPACE__ rollout status deployment/keycloak --timeout=300s

printf '%s\n' '===== Keycloak service ====='
k3s kubectl -n __USER_PORTAL_NAMESPACE__ get service keycloak -o wide
k3s kubectl -n __USER_PORTAL_NAMESPACE__ get endpoints keycloak -o wide

echo 'Keycloak health check passed.'
REMOTE_SCRIPT
)"
}

check_database() {
  run_remote_check \
    "PostgreSQL health" \
    "$(cat <<'REMOTE_SCRIPT'
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

printf '%s\n' '===== PostgreSQL rollout ====='
k3s kubectl -n __USER_PORTAL_NAMESPACE__ rollout status statefulset/postgres --timeout=300s

printf '%s\n' '===== PostgreSQL service ====='
k3s kubectl -n __USER_PORTAL_NAMESPACE__ get service postgres -o wide
k3s kubectl -n __USER_PORTAL_NAMESPACE__ get endpoints postgres -o wide

echo 'PostgreSQL health check passed.'
REMOTE_SCRIPT
)"
}

check_cache() {
  run_remote_check \
    "Redis health" \
    "$(cat <<'REMOTE_SCRIPT'
set -euo pipefail
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

printf '%s\n' '===== Redis rollout ====='
k3s kubectl -n __USER_PORTAL_NAMESPACE__ rollout status statefulset/redis --timeout=300s

printf '%s\n' '===== Redis service ====='
k3s kubectl -n __USER_PORTAL_NAMESPACE__ get service redis -o wide
k3s kubectl -n __USER_PORTAL_NAMESPACE__ get endpoints redis -o wide

echo 'Redis health check passed.'
REMOTE_SCRIPT
)"
}

main() {
  local scope="${1:-all}"

  if [[ "${scope}" == "help" || "${scope}" == "--help" || "${scope}" == "-h" ]]; then
    usage
    return 0
  fi

  if (( $# != 1 && $# != 0 )); then
    usage >&2
    die "Expected at most one health-check scope."
  fi

  case "${scope}" in
    all)
      check_infrastructure
      check_keycloak
      check_database
      check_cache
      ;;
    infrastructure)
      check_infrastructure
      ;;
    keycloak)
      check_keycloak
      ;;
    database)
      check_database
      ;;
    cache)
      check_cache
      ;;
    *)
      usage >&2
      die "Unknown health-check scope: ${scope}"
      ;;
  esac
}

main "$@"
