#!/usr/bin/env bash
# Stable administrator entry point for the DIGITAfrica user portal.
#
# Usage:
#   scripts/admin/user-portal.sh <command>
#
# Commands:
#   context      Show the resolved non-secret deployment context.
#   preflight    Validate local prerequisites and target connectivity.
#   deploy       Reconcile the Keycloak portal deployment.
#   healthcheck  Run read-only Kubernetes readiness checks.
#   help         Show this help text.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/admin/user-portal.sh <command>

Commands:
  context      Show resolved paths and non-secret deployment context.
  preflight    Validate prerequisites, local secrets, and Ansible connectivity.
  deploy       Run the idempotent Keycloak portal deployment.
  healthcheck  Run read-only Keycloak and PostgreSQL readiness checks.
  help         Show this help text.

Environment overrides:
  USER_PORTAL_INVENTORY=/path/to/hosts.ini
  USER_PORTAL_PLAYBOOK=/path/to/site.yml
  USER_PORTAL_TARGET_GROUP=tier1_server
  USER_PORTAL_NAMESPACE=digitafrica
  USER_PORTAL_SECRETS_FILE=/path/to/secrets.yml
USAGE
}

main() {
  local command="${1:-help}"

  case "${command}" in
    context)
      show_context
      ;;
    preflight|deploy)
      shift
      exec "${SCRIPT_DIR}/deploy.sh" "${command}" "$@"
      ;;
    healthcheck)
      shift
      exec "${SCRIPT_DIR}/healthcheck.sh" "$@"
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      usage >&2
      die "Unknown command: ${command}"
      ;;
  esac
}

main "$@"
