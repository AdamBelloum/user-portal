#!/usr/bin/env bash
# Shared functions for user-portal administrator scripts.
# This file must be sourced, not executed directly.

if [[ -n "${USER_PORTAL_COMMON_SH_LOADED:-}" ]]; then
  return 0
fi
readonly USER_PORTAL_COMMON_SH_LOADED=1

readonly USER_PORTAL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly USER_PORTAL_ADMIN_DIR="$(cd "${USER_PORTAL_LIB_DIR}/.." && pwd)"
readonly USER_PORTAL_REPO_ROOT="$(cd "${USER_PORTAL_ADMIN_DIR}/../.." && pwd)"

# Operators may override non-secret deployment paths through their environment.
USER_PORTAL_INVENTORY="${USER_PORTAL_INVENTORY:-${USER_PORTAL_REPO_ROOT}/inventories/prod/hosts.ini}"
USER_PORTAL_PLAYBOOK="${USER_PORTAL_PLAYBOOK:-${USER_PORTAL_REPO_ROOT}/playbooks/site.yml}"
USER_PORTAL_TARGET_GROUP="${USER_PORTAL_TARGET_GROUP:-tier1_server}"
USER_PORTAL_NAMESPACE="${USER_PORTAL_NAMESPACE:-digitafrica}"
USER_PORTAL_SECRETS_FILE="${USER_PORTAL_SECRETS_FILE:-${USER_PORTAL_REPO_ROOT}/inventories/prod/group_vars/all/secrets.yml}"

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

heading() {
  printf '\n%s\n%s\n%s\n' \
    '============================================================' \
    "$*" \
    '============================================================'
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "Required file not found: $1"
}

require_directory() {
  [[ -d "$1" ]] || die "Required directory not found: $1"
}

require_repository_layout() {
  require_file "${USER_PORTAL_REPO_ROOT}/README.md"
  require_file "${USER_PORTAL_PLAYBOOK}"
  require_file "${USER_PORTAL_INVENTORY}"
  require_file "${USER_PORTAL_REPO_ROOT}/inventories/prod/group_vars/all/main.yml"
  require_file "${USER_PORTAL_REPO_ROOT}/roles/k8s_apps/tasks/install.yml"
}

require_ansible_environment() {
  require_command ansible
  require_command ansible-playbook
  require_repository_layout
}

require_local_secrets() {
  local mode

  require_file "${USER_PORTAL_SECRETS_FILE}"
  require_command stat

  mode="$(stat -c '%a' -- "${USER_PORTAL_SECRETS_FILE}")"
  if (( (8#${mode} & 8#077) != 0 )); then
    die "Secrets file must not be accessible to group or other users: ${USER_PORTAL_SECRETS_FILE} (mode ${mode})."
  fi

  if grep -Eq 'CHANGE_ME|<[^>]+>' "${USER_PORTAL_SECRETS_FILE}"; then
    die "Secrets file still contains a template placeholder: ${USER_PORTAL_SECRETS_FILE}."
  fi
}

check_ansible_connectivity() {
  require_ansible_environment
  ansible -i "${USER_PORTAL_INVENTORY}" "${USER_PORTAL_TARGET_GROUP}" -m ansible.builtin.ping
}

run_ansible_playbook() {
  require_ansible_environment
  ansible-playbook -i "${USER_PORTAL_INVENTORY}" "$@"
}

show_context() {
  heading "User-portal administrator context"
  printf 'Repository root : %s\n' "${USER_PORTAL_REPO_ROOT}"
  printf 'Inventory       : %s\n' "${USER_PORTAL_INVENTORY}"
  printf 'Playbook        : %s\n' "${USER_PORTAL_PLAYBOOK}"
  printf 'Target group    : %s\n' "${USER_PORTAL_TARGET_GROUP}"
  printf 'Namespace       : %s\n' "${USER_PORTAL_NAMESPACE}"
  printf 'Secrets file    : %s\n' "${USER_PORTAL_SECRETS_FILE}"
}

confirm() {
  local prompt="$1"
  local reply

  if [[ "${USER_PORTAL_ASSUME_YES:-false}" == "true" ]]; then
    info "Automatically confirmed through USER_PORTAL_ASSUME_YES=true."
    return 0
  fi

  read -r -p "${prompt} [y/N]: " reply
  [[ "${reply}" =~ ^([yY]|[yY][eE][sS])$ ]]
}

run_target_remote() {
  local remote_script="$1"
  local encoded_script

  require_ansible_environment
  require_command base64

  encoded_script="$(printf '%s' "${remote_script}" | base64 | tr -d '\n')"

  ANSIBLE_STDOUT_CALLBACK=default ansible \
    -i "${USER_PORTAL_INVENTORY}" \
    "${USER_PORTAL_TARGET_GROUP}" \
    -b \
    -m ansible.builtin.shell \
    -a "printf '%s' '${encoded_script}' | base64 -d | /bin/bash"
}
