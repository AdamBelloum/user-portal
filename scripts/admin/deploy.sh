#!/usr/bin/env bash
# Validate and deploy the DIGITAfrica user portal.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/admin/deploy.sh <preflight|deploy>

Actions:
  preflight  Validate local prerequisites, secret-file safety, syntax, and SSH/Ansible connectivity.
  deploy     Run preflight, request confirmation, then reconcile playbooks/site.yml.

Set USER_PORTAL_ASSUME_YES=true only for deliberate non-interactive automation.
USAGE
}

run_preflight() {
  heading "User-portal deployment preflight"

  require_ansible_environment
  require_local_secrets
  require_command git

  info "Checking playbook syntax."
  ansible-playbook \
    -i "${USER_PORTAL_INVENTORY}" \
    "${USER_PORTAL_PLAYBOOK}" \
    --syntax-check

  info "Checking Ansible connectivity to ${USER_PORTAL_TARGET_GROUP}."
  check_ansible_connectivity

  if git -C "${USER_PORTAL_REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    info "Checking tracked working-tree whitespace."
    git -C "${USER_PORTAL_REPO_ROOT}" diff --check
  fi

  info "Preflight completed successfully."
}

run_deploy() {
  run_preflight

  heading "User-portal deployment confirmation"
  printf 'Inventory : %s\n' "${USER_PORTAL_INVENTORY}"
  printf 'Playbook  : %s\n' "${USER_PORTAL_PLAYBOOK}"
  printf 'Target    : %s\n' "${USER_PORTAL_TARGET_GROUP}"
  printf 'Namespace : %s\n' "${USER_PORTAL_NAMESPACE}"

  if ! confirm "Reconcile the user-portal deployment now?"; then
    info "Deployment cancelled; no playbook was run."
    return 0
  fi

  heading "Running user-portal deployment"
  run_ansible_playbook "${USER_PORTAL_PLAYBOOK}"

  heading "Deployment completed"
  info "Run scripts/admin/user-portal.sh healthcheck next."
}

main() {
  if (( $# == 0 )); then
    usage
    return 0
  fi

  if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h"         || "${2:-}" == "--help" || "${2:-}" == "-h" ]]; then
    usage
    return 0
  fi

  if (( $# != 1 )); then
    usage >&2
    die "Expected exactly one deployment action."
  fi

  case "$1" in
    preflight)
      run_preflight
      ;;
    deploy)
      run_deploy
      ;;
    *)
      usage >&2
      die "Unknown deployment action: $1"
      ;;
  esac
}

main "$@"
