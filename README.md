# Securing DB Access MGMT with HashiCorp Boundary

## 1. Building Vault and Boundary clusters in HCP

The **Plataform** directory contains:

* The code to build a Vault and Boundary cluster in HCP together with a VPC in your AWS account.
* That VPC gets connected to HCP (where Vault is deployed) by means of a VPC peering with an HVN.
* After deploying the infrastructure we set a number of environmental variables that are required for the upcoming deployments.
* Finally, we authenticate with Boundary using the credentials we have defined within the `terraform.tfvars` file. Vault cluster is configured to send logs to Datadog.

```bash
<export AWS Creds>
cd Plataform/
# Initialize TF
terraform init
# Requires interactive login to HCP to approve cluster creation
terraform apply -auto-approve
export BOUNDARY_ADDR=$(terraform output -raw boundary_public_url)
export VAULT_ADDR=$( terraform output -raw vault_public_url)
export VAULT_NAMESPACE=admin
export VAULT_TOKEN=$(terraform output -raw vault_token)
# Log to boundary interactively using password Auth with admin user
boundary authenticate
export TF_VAR_authmethod=$(boundary auth-methods list -format json | jq -r '.items[0].id')
```

> Note: This tutorial is supposed to be run in secuntial order making sure the enviromental variable installed above are used

### 1.1. Inputs

| Variable            | Type   | Example                          | Description                                      | Required |
| ------------------- | ------ | -------------------------------- | ------------------------------------------------ | -------- |
| username            | String | "admin"                          | Boundary initial administrative account username | Yes      |
| password            | String | "N0tS0Secr3tPas$w0rd"            | Boundary initial administrative account password | Yes      |
| vault_tier          | String | "plus_small"                     | HCP Vault Tier                                   | Yes      |
| boundary_tier       | String | "PLUS"                           | HCP Boundary Tier                                | Yes      |
| datadog_api_key     | String | `<hex-api-key>`                | Datadog API Key                                  | Optional |
| aws_vpc_cidr        | String | "10.0.0.0/8"                     | Class A Must be used                             | Yes      |
| vault_cluster_id    | String | "hcp-vault-cluster-for-boundary" | HCP Vault Cluster Name                           | Yes      |
| boundary_cluster_id | String | "hcp-boundary-cluster"           | HCP Boundary Cluster Name                        | Yes      |

## 2. Build Databases

The second steps consist on an EC2 instance deployed in a Public subnet (not quite the use case for Boundary). We are going to create a public key that will be associated to the instance and at the same time will be assigned to a Static Credential Store within Boundary. We are also going to build a route table that will connect the subnet where we are deploying the instance with HCP HVN.

```bash
cd ../2_First_target
terraform init
# We will be creating first the key
terraform apply -auto-approve -target=aws_key_pair.ec2_key -target=tls_private_key.rsa_4096_key
# Then the rest of the configuration
terraform apply -auto-approve
```
