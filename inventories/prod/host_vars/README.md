# Local per-host Ansible credentials

Do not store SSH or sudo passwords in `hosts.ini` or any tracked file.

When password-based access is required for a host, create this ignored local file:

```text
inventories/prod/host_vars/<inventory-hostname>/secrets.yml

```

Example:

```yaml
ansible_ssh_pass: "replace-locally"
ansible_become_password: "replace-locally"
```

Protect each local credential file:

```bash
chmod 600 inventories/prod/host_vars/<inventory-hostname>/secrets.yml
```

Prefer SSH keys and tightly scoped passwordless `sudo` where feasible.
