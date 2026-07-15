# Publish the env0 deployment launchers

The source repository is:

```text
https://github.com/lefred/privacy-first-stack-terraform
```

Create five env0 Terraform templates. Each uses this repository with a different Terraform working directory.

| Template name | Terraform working directory |
| --- | --- |
| Privacy Stack – AWS | `aws` |
| Privacy Stack – Azure | `azure` |
| Privacy Stack – Google Cloud | `gcp` |
| Privacy Stack – OCI | `oci` |
| Privacy Stack – OpenStack | `openstack` |

Pin each template to a tested Git tag such as `v1.0.0`, rather than deploying directly from `main`. This makes public deployments reproducible and lets you choose when users receive an update.

## Deployment form

env0 discovers the Terraform inputs from the selected directory. Give infrastructure choices safe defaults and mark passwords and credentials sensitive.

Common fields include:

- `deployment_mode`: `consolidated` by default, or `distributed` for three VMs.
- Cloud region and the provider-specific project, subscription, compartment, or tenant fields.
- `ssh_public_key`, or the corresponding OCI public-key content variable.
- `admin_cidr`; require the deployer's public IP as a `/32` instead of allowing SSH from the whole internet.
- `mariadb_root_password`.
- `nextcloud_db_password`.
- `passbolt_db_password`.
- `nextcloud_admin_password`.
- Optional `passbolt_domain`.

The optional network/subnet identifier lets a deployer reuse existing infrastructure. If omitted, the Terraform adapter creates the required network resources.

## Authentication

Prefer an env0 cloud-account integration using OIDC or workload identity. If static credentials are necessary, users should store them as sensitive values in their own env0 organization. Never place credentials in the Git repository, template defaults, `.tfvars` files, or launch URLs.

OCI remote workers cannot read paths on a user's computer. Supply OCI private-key content through the sensitive `private_key` Terraform variable, or use a supported principal authentication mode. Supply SSH public-key content rather than a local public-key path.

## Connect the README buttons

After creating each template:

1. Open its env0 Run/Launch page.
2. Copy the generated launch URL.
3. In `README.md`, replace the provider's relative target—for example `](aws)`—with that URL.
4. Test it in a private browser session and confirm the expected sign-in or onboarding page appears.
5. Verify that the URL contains no credential, API key, or organization access token.

Repeat this for all five providers. Keep local-directory links elsewhere in the README so users can still inspect the Terraform configuration before deploying.

## Release checklist

1. Run `make bundle` and confirm all five `terraform validate` checks pass.
2. Commit the source and create a tested version tag.
3. Point every env0 template at that tag.
4. Test every launch link while signed out.
5. Run at least a plan for each provider.
6. Clearly document which providers have completed an actual apply test.
