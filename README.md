# DigitAfrica user-portal

Deploying Keycloak on a given K3s cluster.

## What this deploys (high level)

Current implementation supports the following deployments:
* Tier - 1: Keycloak on a k3s instance. Once it is instantiated, other services can use the instance for identification and authentication.

Current code has been tested using a three-node cluster, based on the AMD64 virtual machines.

## Configuration for the BP

Hosts need to be declared in the ```inventories/prod/hosts.ini``` file.

```ini
### TIER 1 NODES ###
[tier1_server]
digitafrica-edge-node1 ansible_host=10.64.45.176 ansible_ssh_pass=REDACTED ansible_become_pass=REDACTED

[tier1_agents]
digitafrica-edge-node2 ansible_host=10.64.45.179 ansible_ssh_pass=REDACTED ansible_become_pass=REDACTED
digitafrica-edge-node3 ansible_host=10.64.45.175 ansible_ssh_pass=REDACTED ansible_become_pass=REDACTED

[tier1:children]
tier1_server
tier1_agents

[all:vars]
ansible_user=ubuntu
ansible_become=true
#ansible_ssh_common_args='-o ProxyJump=proxy@bastion1.theblueprintfactory.org'
```

### Environment Configuration

Production configuration is split into two files:

- `inventories/prod/group_vars/all/main.yml` contains non-secret settings.
- `inventories/prod/group_vars/all/secrets.yml.example` is copied locally to `secrets.yml` and populated with newly generated passwords. `secrets.yml` is ignored by Git and must never be committed.

Keycloak requires trusted, externally supplied TLS material. `tls_mode` must be `provided`; self-signed TLS is unsupported for this OIDC deployment. The deployment hosts must contain `keycloak.crt` and `keycloak.key` in the configured `tls_workdir`.

Keycloak is exposed only through the Traefik HTTPS Ingress at the first configured `tls_domains` hostname. Direct Keycloak NodePort access is intentionally unsupported.

## Deploying the BP

To install on the nodes declared at the hosts.ini file, ensure that the deploying machine has ```ansible``` and ```ssh-pass``` installed, and ssh access to all the machines.

```bash
ansible-galaxy collection install -r requirements.yml
```

To install the BP, use the following command:

```bash
ansible-playbook -i inventories/prod/hosts.ini playbooks/site.yml
```

You can uninstall the current version of the BP using the following command:

```bash
ansible-playbook -i inventories/prod/hosts.ini playbooks/site.yml -e digitafrica_uninstall=true -e digitafrica_confirm_user_portal_uninstall=true
```

# OIDC Authentication Implementation

## Overview

In the Tier-1 deployment, authentication has been implemented using **OpenID Connect (OIDC)**.

The user portal is used to be the Identity Provider (IdP) for DigitAfrica. In this setup, the IdP is **Keycloak**.

## Keycloak admin console

Access the Keycloak administration console through:

```text
https://<first value in tls_domains>
```

Sign in with `tier1.user_portal.admin_user` and the bootstrap administrator password stored only in the local `secrets.yml`. Do not access Keycloak directly through a NodePort.

## Using SLICES as Identity Provider (optional)

This setup can use SLICES as an external Identity Provider via Keycloak.

If you want to implement a service with SLICES OAuth, follow the official documentation:
[https://doc.slices-ri.eu/dev/website_oauth.html](https://doc.slices-ri.eu/dev/website_oauth.html)

To integrate SLICES-RI identity provider, go to **Identity Providers** and then:

1. Add OpenID Connect v1.0 Identity provider
2. Define the alias of your choice, this will determine the redirect URL to be used. It is of the form `https://{user_portal_fqdn}/realms/{realm}/broker/{alias}/endpoint` where `user_portal_fqdn` is the `host:port` to be used to reach your user portal from the outside, `realm` is the realm in which you add the identity provider, and `alias` is the alias you chose for this provider.
3. Use a discovery endpoint and specify: `https://portal.slices-ri.eu/.well-known/openid-configuration`
4. Set the client ID and client secret that you received from your request to SLICES (see above).

Once it is created, go and configure the provider and in the advanced pane, and set the scopes to be `openid userinfo projects`.

Then create two mappers:

1. Mapper type=*Attribute Importer*, claim=`first_name`, User attribute Name=`firstName`
2. Mapper type=*Attribute Importer*, claim=`last_name`, User attribute Name=`lastName`

The mappers are required to seamlessly create SLICES users in Keycloak. If not provided, then users will be asked to provide their first and last names.