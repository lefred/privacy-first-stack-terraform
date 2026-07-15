# Privacy-First Stack: Native multi-cloud compute bundle

This bundle installs the [Privacy-First Stack](https://ecohub.mariadb.org/solution-stacks/privacy-first-stack) (MariaDB Server, Nextcloud, and Passbolt) directly on Ubuntu 24.04 compute instances.

Supported roots: `aws`, `azure`, `gcp`, `openstack`, and `oci`.

## Choose your cloud

<!-- Replace each provider link with its env0 Run/Launch URL after creating the five templates. -->

| | | |
|:---:|:---:|:---:|
| [![Deploy on AWS](https://img.shields.io/badge/Deploy-AWS-FF9900?style=for-the-badge&logo=amazonwebservices&logoColor=white)](aws) | [![Deploy on Azure](https://img.shields.io/badge/Deploy-Azure-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)](azure) | [![Deploy on Google Cloud](https://img.shields.io/badge/Deploy-Google_Cloud-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)](gcp) |
| [![Deploy on OCI](https://img.shields.io/badge/Deploy-Oracle_Cloud-F80000?style=for-the-badge&logo=oracle&logoColor=white)](oci) | [![Deploy on OpenStack](https://img.shields.io/badge/Deploy-OpenStack-ED1944?style=for-the-badge&logo=openstack&logoColor=white)](openstack) | |

The buttons currently open the selected provider configuration. 

## Deployment topology

Every provider exposes the same `deployment_mode` variable:

- `consolidated` (default): MariaDB, Passbolt, and Nextcloud share one VM.
- `distributed`: Terraform creates three VMs, one for each service. Passbolt and Nextcloud connect to MariaDB over the private network.

In distributed mode the database VM has no public IP. TCP 3306 is limited to `database_allowed_cidr`; set this to the CIDR of the selected subnet when reusing a network. Passbolt retains the provider's `public_ip` output and Nextcloud is exposed through `nextcloud_public_ip`. Switching an existing deployment between modes changes compute resources and should be reviewed carefully in the plan. Distributed mode also triples the VM and boot-volume footprint.

## Existing or managed infrastructure

Each adapter supports two modes:

| Provider | Reuse input | Created when omitted |
| --- | --- | --- |
| AWS | `subnet_id` | VPC, public subnet, internet gateway, route table |
| Azure | `resource_group_name`, `subnet_id` | Resource group, VNet, subnet |
| GCP | `subnetwork` | Custom VPC network and regional subnet |
| OpenStack | `network_id`, `image_id` | Tenant network, subnet, router; Ubuntu image is discovered |
| OCI | `subnet_id`, `image_id`, `availability_domain` | VCN, subnet, internet gateway, route table; Ubuntu image and availability domain are discovered |

When an existing subnet is supplied, its routing and internet/NAT access remain the operator's responsibility. The VM needs outbound HTTPS during first boot to install packages. Provider-specific CIDRs and names can be overridden through the variables documented in each adapter's `variables.tf`.

### OCI authentication

OCI API-key authentication requires the tenancy OCID, user OCID, fingerprint, region, and either the private-key content or a key path. For HCP Terraform and env0, provide `private_key` as a sensitive workspace variable because a local `private_key_path` normally does not exist on the remote runner. Alternatively, set `auth` to `InstancePrincipal`, `ResourcePrincipal`, `SecurityToken`, or `OKEWorkloadIdentity` and configure the corresponding OCI identity and environment.

The availability-domain lookup uses `tenancy_ocid` when provided. `compartment_id` remains the target compartment for images and deployed resources.

Choose one provider directory, copy its `terraform.tfvars.example` to `terraform.tfvars`, set all required values, then run `terraform init`, `terraform plan`, and `terraform apply`. For HCP Terraform or env0, set the chosen provider directory as the working directory and store all password values as sensitive workspace variables.

Cloud-init progress is available on the instance in `/var/log/privacy-stack-install.log`. Terraform completion means the VM exists; application installation can continue for several minutes afterward. The marker `/var/lib/privacy-stack-ready` indicates completion.

In consolidated mode the native endpoints are Passbolt on ports 80/443 and Nextcloud on port 8080. Distributed mode keeps the same application ports, but each endpoint uses its own public IP. Provider firewall rules and the Ubuntu guest firewall rules allow these ports. No port forwarding is used.

Passbolt is configured for HTTPS using a self-signed certificate whose subject alternative names include the detected public IP and, when provided, `passbolt_domain`. HTTP redirects to HTTPS. Browsers will warn until the certificate is explicitly trusted; for production, replace it with a certificate from a trusted CA or put a managed TLS load balancer/reverse proxy in front. Restrict SSH with `admin_cidr`; the application CIDR defaults should also be narrowed for private deployments.

The generated cloud-init and Terraform state contain secrets. Use encrypted remote state with tightly restricted access.

## Local deployment

```sh
git clone https://github.com/lefred/privacy-first-stack-terraform.git
cd privacy-first-stack-terraform/oci # or aws, azure, gcp, openstack
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```
