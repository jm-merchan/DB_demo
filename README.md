# Securing DB Access MGMT with HashiCorp Boundary

#### Prerequisites

* Terraform, Vault and Boundary CLI installed on your environment.
* psql client
* mongosh client

## 1. Building Vault and Boundary clusters in HCP and Database (RDS and DocumentDB) instances

The **Plataform** directory contains:

* The code to build a Vault and Boundary cluster in HCP together with a VPC in your AWS account.
* That VPC gets connected to HCP (where Vault is deployed) by means of a VPC peering with an HVN.
* The VPC contains a Public and Private Subnet. In the private subnet we are deploying an RDS instance with a PostgreSQL engine (the database will be configured in a second steps) and DocumentDB cluster
* After deploying the infrastructure we set a number of environmental variables that are required for the upcoming deployments.
* Finally, we authenticate with Boundary using the credentials we have defined within the `terraform.tfvars` file. Vault cluster is configured to send logs to Datadog (simply comment the stanzas to avoid this).

```bash
<export AWS Creds>
<export HCP Creds or interactive login during apply>
cd 1_Plataform/
# Initialize TF
terraform init
# Requires interactive login to HCP to approve cluster creation
terraform apply -auto-approve
export BOUNDARY_ADDR=$(terraform output -json | jq -r .boundary_public_url.value)
export VAULT_ADDR=$(terraform output -raw vault_public_url)
export VAULT_NAMESPACE=admin
export VAULT_TOKEN=$(terraform output -raw vault_token)
# Log to boundary interactively using password Auth with admin user
boundary authenticate
export TF_VAR_authmethod=$(boundary auth-methods list -format json | jq -r '.items[0].id')
```

> Note: This tutorial is supposed to be run in secuntial order making sure the enviromental variable installed above are used

### 1.1. Inputs

| Variable              | Type   | Example                          | Description                                      | Required                                                                                                                                                       |
| --------------------- | ------ | -------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| username              | String | "admin"                          | Boundary initial administrative account username | Yes                                                                                                                                                            |
| password              | String | "N0tS0Secr3tPas$w0rd"            | Boundary initial administrative account password | Yes                                                                                                                                                            |
| vault_tier            | String | "plus_small"                     | HCP Vault Tier                                   | Yes                                                                                                                                                            |
| boundary_tier         | String | "PLUS"                           | HCP Boundary Tier                                | Yes                                                                                                                                                            |
| datadog_api_key       | String | `<hex-api-key>`                | Datadog API Key                                  | Optional, remove `metrics_config` and `audit_log_config` stanzas in  `vault-deploy.tf`. Also remove variable `datadog_api_key` from `variables.tf` |
| aws_vpc_cidr          | String | "10.0.0.0/16"                    | Class A Must be used                             | Yes                                                                                                                                                            |
| vault_cluster_id      | String | "hcp-vault-cluster-for-boundary" | HCP Vault Cluster Name                           | Yes                                                                                                                                                            |
| boundary_cluster_id   | String | "hcp-boundary-cluster"           | HCP Boundary Cluster Name                        | Yes                                                                                                                                                            |
| db_username           | String | "demo"                           | Username of the master database user             | Yes                                                                                                                                                            |
| AWS_ACCESS_KEY_ID     | env    |                                  | AWS Access Key                                   | No, you can use UserID                                                                                                                                         |
| AWS_SECRET_ACCESS_KEY | env    |                                  |                                                  | No, you can use SecretID                                                                                                                                       |
| AWS_SESSION_TOKEN     | env    |                                  |                                                  | No                                                                                                                                                             |

### 1.2 Outputs

| Variable               | Type   | Description                       | Example                                                                                                                    |
| ---------------------- | ------ | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| boundary_public_url    | String | HCP Boundary URL                  | boundary_public_url = "https://7d018f9c-ee36-4ac4-90b6-10b465770d5c.boundary.hashicorp.cloud"                              |
| docdb_cluster_endpoint | String | DocumentDB FQDN                   | docdb_cluster_endpoint = "docdb-cluster.cluster-cqxy3m8bffq6.eu-west-2.docdb.amazonaws.com"                                |
| peering_id             | String | HCP peering id                    | peering_id = "pcx-00b430b2a631dbb85"                                                                                       |
| rds_hostname           | String | PostgresSQL FQDN                  | rds_hostname = "boundarydemo.cqxy3m8bffq6.eu-west-2.rds.amazonaws.com"                                                     |
| vault_private_url      | String | Vault private endpoint FQDN (API) | vault_private_url = "https://hcp-vault-cluster-for-boundary-private-vault-4ef8978f.1bdf4150.z1.hashicorp.cloud:8200"       |
| vault_proxy_endpoint   | String | Vault FQDN for UI access          | vault_proxy_endpoint = "https://hcp-vault-cluster-for-boundary-http-vault-d22512ab.j.cloud.hashicorp.com"                  |
| vault_public_url       | String | Vault public endpoint FQDN (API)  | vault_public_url = "https://hcp-vault-cluster-for-boundary-public-vault-4ef8978f.1bdf4150.z1.hashicorp.cloud:8200"         |
| vault_token            | String | Vault administrative token        | vault_token = "hvs.CAESII1E2spw7s563IIkV8sD7_NQ0CnEJ1CkKfi-zhq24Xt9GiYKImh2cy52TXdYSFpaSFFpNmpBWmZWSmRBYjFiT2gubHNPRkYQeQ" |
| vpc                    | String | VPC id                            | vpc = "vpc-026c5921344de499e"                                                                                              |

## 2. Create Self-Managed Worker, configure RDS and Boundary/Vault

In this second step we are going to deploy an EC2 that will play two roles:

* On the one hand, it will work as Boundary Worker that will allow the connection to the Database and also to Vault itself via the private endpoint.
* On the other hand, it will serve as database configuration manager. It will create the users and roles that will be leverage by Vault's dynamic secret engine as well as create a table with mock data.

Additionally, we are going to configure Vault Dynamic Secret Engine with 4 distint roles and Boundary logic within the Project:

* Scopes (Organization and Project)
* Credential Stores (using Vault to generated JIT credentials with TTL), Credential Libraries (the Vault paths)
* Host Catalog, Host Set and Hosts (to hold our RDS instance)
* Targets (mapping the RDS with the different credentials)

Targets are a wrapper of host (host-sets) and permisions (in the form of credentials). In this demo we have a single host, but different set of `Credential Libraries` associated with different `paths` in Vault that correspond to separated roles in our database.

![1706094472972](image/README/1706094472972.png)

```bash
cd ../2_Config
terraform init
terraform apply -auto-approve
```

### 2.1. Inputs

| Variable          | Type   | Example               | Description                                                            | Required |
| ----------------- | ------ | --------------------- | ---------------------------------------------------------------------- | -------- |
| username          | String | "admin"               | Boundary initial administrative account username                       | Yes      |
| password          | String | "N0tS0Secr3tPas$w0rd" | Boundary initial administrative account password                       | Yes      |
| region            | String | "eu-west-2"           | AWS Region                                                             | Yes      |
| key_pair_name     | String | "cert"                | Name of the key pair that will be used to create the EC2 instance      | Yes      |
| authmethod        | String | "ampw_g7gkG7hioT"     | Boundary Auth Method ID. Introduced as enviromental variable in step 1 | Yes      |
| db_username       | String | "demo"                | Username of the master database user                                   | Yes      |
| BOUNDARY_ADDR     | env    |                       | Boundary URL                                                           | Yes      |
| VAULT_ADDR        | env    |                       | Vault Public URL                                                       | Yes      |
| VAULT_TOKEN       | env    |                       | Vault admin token                                                      | Yes      |
| TF_VAR_authmethod | env    |                       | auth method id                                                         | Yes      |

### 2.2 Outputs

| Variable                            | Type   | Description                                                  | Example                                                                |
| ----------------------------------- | ------ | ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| connect_documentDB_target_dba       | String | Commands to connect to DocumentDB DBA target                 | terraform output -raw connect_documentDB_target_readonly              |
| connect_documentDB_target_readonly  | String | Commands to connect to DocumentDB readonly target            | terraform output -raw connect_documentDB_target_readonly              |
| connect_documentDB_target_readwrite | String | Commands to connect to DocumentDB readwrite target          | terraform output -raw connect_documentDB_target_readonly              |
| connect_rds_target_dba              | String | Command to connect to RDS DBA target                         | boundary connect postgres -target-id ttcp_UflbyKyPWb -dbname northwind |
| connect_rds_target_readonly         | String | Command to connect to RDS readonly target                    | boundary connect postgres -target-id ttcp_y5a14LzaOT -dbname northwind |
| connect_rds_target_readwrite        | String | Command to connect to RDS readwrite target                   | boundary connect postgres -target-id ttcp_ezWrfC1F8h -dbname northwind |
| documentDB_target_dba               | String | DocumentDB DBA Target ID                                     | ttcp_5KF7b2nemT                                                        |
| documentDB_target_readonly          | String | DocumentDB ReadOnly Target ID                                | ttcp_cmdRTvMpOX                                                        |
| documentDB_target_readwrite         | String | DocumentDB ReadWrite Target ID                               | ttcp_AV0272rFCb                                                        |
| rds_target_dba                      | String | RDS DBA Target ID                                            | ttcp_UflbyKyPWb                                                        |
| rds_target_readonly                 | String | RDS ReadOnly Target ID                                       | ttcp_y5a14LzaOT                                                        |
| rds_target_readwrite                | String | RDS ReadWrite Target ID                                      | ttcp_ezWrfC1F8h                                                        |
| ssh_worker_fqdn                     | String | Command to connect to Boundary Worker via SSH (ec2 instance) | ssh -i cert.pem ubuntu@ec2-35-177-0-38.eu-west-2.compute.amazonaws.com |
| worker_fqdn                         | String | Boundary Worker Public FQDN (ec2 instance)                   | ec2-35-177-0-38.eu-west-2.compute.amazonaws.com                        |

## 3. Mapping IdP (OIDC) Users to targets based on roles

In this step we are going to leverage Auth0 dev account to build an OIDC integration between Auth0 and Boundary. The first task will be to create an Application with access to Auth0 MGMT API:

* Go to Applications, then click on [+ Create Application] button and select "Machine to Machine Applications".
* Click on Create.
* In the next page, in the drop-down menu select "Auth0 Management API" and provide All Permissions.
* Finally click on Authorize

![1706200768546](image/README/1706200768546.png)

After its being created we can copy some of the details and pass them as enviromental variables so the Auth0 provider can consume them. Go to the setting tab and retrieve the values.

![1706200846923](image/README/1706200846923.png)

Export those values as enviromental variables and run the code

```bash
export AUTH0_DOMAIN="<domain>"
export AUTH0_CLIENT_ID="<client-id>" 
export AUTH0_CLIENT_SECRET="<client_secret>"
cd ../3_RBAC
terraform init
terraform apply -auto-approve
```

* We are setting up Boundary to use Auth0 for authentication, defining the proper callback URLs.
* We are creating 4 users that will be mapped to different roles within Boundary.

You can test it via CLI using the email address of any of the 3 users returned as Terraform output

```bash
boundary authenticate oidc -auth-method-id $(terraform output -raw auth_method_id)
boundary targets list -scope-id $(terraform output -raw project-scope-id) -format json | jq -r .
```

### 3.1. Inputs

| Variable            | Type   | Example               | Description                                                                 | Required |
| ------------------- | ------ | --------------------- | --------------------------------------------------------------------------- | -------- |
| username            | String | "admin"               | Boundary initial administrative account username                            | Yes      |
| password            | String | "N0tS0Secr3tPas$w0rd" | Boundary initial administrative account password                            | Yes      |
| auth0_password      | String | "N0tS0Secr3tPas$w0rd" | A password that will be associated to every user account we create in Auth0 |          |
| authmethod          | String | "ampw_g7gkG7hioT"     | Boundary Auth Method ID. Introduced as enviromental variable in step 1      | Yes      |
| BOUNDARY_ADDR       | env    |                       | Boundary URL                                                                | Yes      |
| TF_VAR_authmethod   | env    |                       | auth method id                                                              |          |
| AUTH0_DOMAIN        | env    |                       |                                                                             |          |
| AUTH0_CLIENT_ID     | env    |                       |                                                                             |          |
| AUTH0_CLIENT_SECRET | env    |                       |                                                                             |          |

### 3.2 Outputs

| Variable                  | Type   | Description                                            | Example                                                      |
| ------------------------- | ------ | ------------------------------------------------------ | ------------------------------------------------------------ |
| auth_method_id            | String | OIDC Auth Method ID                                    | amoidc_kFalRmMWZw                                            |
| boundary_authenticate_cli | String | Command to authenticate to boundary via Auth0          | boundary authenticate oidc -auth-method-id amoidc_kFalRmMWZw |
| password                  | String | Password for all users created                         | Passw0rd123!                                                 |
| project-scope-id          | String | Project ID scope where all resources have been created | p_3qnPearCT1                                                 |
| user_dba_email            | String | Email address for DBA user                             | dba@boundaryproject.io                                       |
| user_readonly_email       | String | Email address for ReadOnly user                        | readonly@boundaryproject.io                                  |
| user_readwrite_email      | String | Email address for ReadWrite user                       | readwrite@boundaryproject.io                                 |

# Workflows

## RDS DBA

```sql
> export BOUNDARY_ADDR=https://72a20d60-b9c3-438d-8664-dfcbaaaf0867.boundary.hashicorp.cloud
> boundary authenticate oidc -auth-method-id amoidc_l17XJAoZXb
Opening returned authentication URL in your browser...
https://dev-q6ml3431eugrpfdc.us.auth0.com/authorize?client_id=prJEtaNbo....

Authentication information:
  Account ID:      acctoidc_mhycKeWZdd
  Auth Method ID:  amoidc_l17XJAoZXb
  Expiration Time: Tue, 13 Feb 2024 07:48:44 CET
  User ID:         u_W4zdXRaLQB

The token name "default" was successfully stored in the chosen keyring and is not displayed here.

> boundary targets list -recursive

Target information:
  ID:                    ttcp_f6iyFgSkzK
    Scope ID:            p_MfRkfe58Bd
    Version:             3
    Type:                tcp
    Name:                RDS DBA Access
    Description:         RDS DBA Permissions
    Authorized Actions:
      authorize-session
      read

  ID:                    ttcp_1Xky8n4iI8
    Scope ID:            p_MfRkfe58Bd
    Version:             3
    Type:                tcp
    Name:                DocumentDB DBA Access
    Description:         DocumentDB: DBA Permissions
    Authorized Actions:
      read
      authorize-session
 
> boundary connect postgres -target-id ttcp_f6iyFgSkzK -dbname northwind
psql (14.10 (Homebrew), server 13.13)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

northwind=> \conninfo
You are connected to database "northwind" as user "v-token-to-dba-wNVIPCDSDa1RNUeLajDv-1707202187" on host "127.0.0.1" at port "57865".
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)

northwind=> create database dbatest;
CREATE DATABASE

northwind=> \l
                                                                        List of databases
   Name    |                     Owner                      | Encoding |   Collate   |    Ctype    |                      Access privileges   
-----------+------------------------------------------------+----------+-------------+-------------+--------------------------------------------------------------
 dbatest   | v-token-to-dba-wNVIPCDSDa1RNUeLajDv-1707202187 | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 northwind | demo                                           | UTF8     | en_US.UTF-8 | en_US.UTF-8 | demo=CTc/demo                                               +
           |                                                |          |             |             | "v-token-to-readonly-HXt20oWkIjJ20qHIfTx2-1707201737"=c/demo+
           |                                                |          |             |             | "v-token-to-dba-wNVIPCDSDa1RNUeLajDv-1707202187"=c/demo
 postgres  | demo                                           | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 rdsadmin  | rdsadmin                                       | UTF8     | en_US.UTF-8 | en_US.UTF-8 | rdsadmin=CTc/rdsadmin                                       +
           |                                                |          |             |             | rdstopmgr=Tc/rdsadmin
 template0 | rdsadmin                                       | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/rdsadmin                                                 +
           |                                                |          |             |             | rdsadmin=CTc/rdsadmin
 template1 | demo                                           | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/demo                                                     +
           |                                                |          |             |             | demo=CTc/demo
(6 rows)

northwind=> CREATE ROLE bob;
CREATE ROLE
northwind=> \du
                                                                                 List of roles
                      Role name                      |                         Attributes                         |                          Member of      
-----------------------------------------------------+------------------------------------------------------------+-------------------------------------------------------------
 bob                                                 | Cannot login                                               | {}
 demo                                                | Create role, Create DB                                    +| {rds_superuser}
                                                     | Password valid until infinity                              | 
 rds_ad                                              | Cannot login                                               | {}
 rds_iam                                             | Cannot login                                               | {}
 rds_password                                        | Cannot login                                               | {}
 rds_replication                                     | Cannot login                                               | {}
 rds_superuser                                       | Cannot login                                               | {pg_monitor,pg_signal_backend,rds_replication,rds_password}
 rdsadmin                                            | Superuser, Create role, Create DB, Replication, Bypass RLS+| {}
                                                     | Password valid until infinity                              | 
 rdsrepladmin                                        | No inheritance, Cannot login, Replication                  | {}
 rdstopmgr                                           | Password valid until infinity                              | {pg_monitor}
 v-token-to-dba-wNVIPCDSDa1RNUeLajDv-1707202187      | Create role, Create DB                                    +| {rds_superuser}
                                                     | Password valid until 2024-02-06 07:49:52+00                | 
 v-token-to-readonly-HXt20oWkIjJ20qHIfTx2-1707201737 | Password valid until 2024-02-06 07:42:22+00                | {}

northwind=> CREATE TABLE "test" ("fullName" varchar(255), "isUser" varchar(255), "rating" varchar(255));
INSERT INTO "test" ("fullName", "isUser", "rating")

        VALUES ('Almeda Shields', 'true', '⭐️⭐️'), ('Daniele Upward', 'false', '⭐️⭐️');
CREATE TABLE
INSERT 0 2
northwind=> \dt
                                    List of relations
 Schema |          Name          | Type  |                     Owner  
--------+------------------------+-------+------------------------------------------------
 public | categories             | table | demo
 public | customer_customer_demo | table | demo
 public | customer_demographics  | table | demo
 public | customers              | table | demo
 public | employee_territories   | table | demo
 public | employees              | table | demo
 public | order_details          | table | demo
 public | orders                 | table | demo
 public | products               | table | demo
 public | region                 | table | demo
 public | shippers               | table | demo
 public | suppliers              | table | demo
 public | territories            | table | demo
 public | test                   | table | v-token-to-dba-wNVIPCDSDa1RNUeLajDv-1707202187
 public | us_states              | table | demo
(15 rows)

northwind=> select * from us_states;
 state_id |      state_name      | state_abbr | state_region 
----------+----------------------+------------+--------------
        1 | Alabama              | AL         | south
        2 | Alaska               | AK         | north
        3 | Arizona              | AZ         | west
        4 | Arkansas             | AR         | south
        5 | California           | CA         | west
        6 | Colorado             | CO         | west
        7 | Connecticut          | CT         | east
        8 | Delaware             | DE         | east
        9 | District of Columbia | DC         | east
       10 | Florida              | FL         | south
       11 | Georgia              | GA         | south
       12 | Hawaii               | HI         | west
       13 | Idaho                | ID         | midwest
       14 | Illinois             | IL         | midwest
       15 | Indiana              | IN         | midwest
       16 | Iowa                 | IO         | midwest
       17 | Kansas               | KS         | midwest
       18 | Kentucky             | KY         | south
       19 | Louisiana            | LA         | south
       20 | Maine                | ME         | north
       21 | Maryland             | MD         | east
       22 | Massachusetts        | MA         | north
       23 | Michigan             | MI         | north
       24 | Minnesota            | MN         | north
       25 | Mississippi          | MS         | south
       26 | Missouri             | MO         | south
       27 | Montana              | MT         | west
       28 | Nebraska             | NE         | midwest
       29 | Nevada               | NV         | west
       30 | New Hampshire        | NH         | east
       31 | New Jersey           | NJ         | east
       32 | New Mexico           | NM         | west
       33 | New York             | NY         | east
       34 | North Carolina       | NC         | east
       35 | North Dakota         | ND         | midwest
       36 | Ohio                 | OH         | midwest
       37 | Oklahoma             | OK         | midwest
       38 | Oregon               | OR         | west
       39 | Pennsylvania         | PA         | east
       40 | Rhode Island         | RI         | east
       41 | South Carolina       | SC         | east
       42 | South Dakota         | SD         | midwest
       43 | Tennessee            | TN         | midwest
       44 | Texas                | TX         | west
       45 | Utah                 | UT         | west
       46 | Vermont              | VT         | east
       47 | Virginia             | VA         | east
       48 | Washington           | WA         | west
       49 | West Virginia        | WV         | south
       50 | Wisconsin            | WI         | midwest
       51 | Wyoming              | WY         | west
(51 rows)

northwind=> select * from test;
    fullName    | isUser | rating 
----------------+--------+--------
 Almeda Shields | true   | ⭐️⭐️
 Daniele Upward | false  | ⭐️⭐️
(2 rows)
```

## RDS ReadWrite

```bash
> export BOUNDARY_ADDR=https://72a20d60-b9c3-438d-8664-dfcbaaaf0867.boundary.hashicorp.cloud

> boundary authenticate oidc -auth-method-id amoidc_l17XJAoZXb  
Opening returned authentication URL in your browser...
https://dev-q6ml3431eugrpfdc.us.auth0.com/authorize?client_id=prJEtaNbo9NqHLf7tjKeDM5GWfmI6amc&max_age=0&nonce=D4Jv2CXeWPDzOIe6ubMv&redirect_uri=https%3A%2F%2F72a20d60-b9c3-438d-8664-dfcbaaaf0867.boundary.hashicorp.cloud%2Fv1%2Fauth-methods%2Foidc%3Aauthenticate%3Acallback&response_type=co-...

Authentication information:
  Account ID:      acctoidc_tVPFQqd66p
  Auth Method ID:  amoidc_l17XJAoZXb
  Expiration Time: Tue, 13 Feb 2024 10:54:01 CET
  User ID:         u_AWdADm7539

The token name "default" was successfully stored in the chosen keyring and is not displayed here.


> boundary targets list -recursive

Target information:
  ID:                    ttcp_O4XOrZkkm2
    Scope ID:            p_MfRkfe58Bd
    Version:             3
    Type:                tcp
    Name:                DocumentDB Read/Write Access
    Description:         DocumentDB: readWriteAllDBs
    Authorized Actions:
      read
      authorize-session

  ID:                    ttcp_NJQ4NO87QJ
    Scope ID:            p_MfRkfe58Bd
    Version:             3
    Type:                tcp
    Name:                RDS Read/Write Access
    Description:         RDS: SELECT, INSERT, UPDATE, DELETE
    Authorized Actions:
      read
      authorize-session


> boundary connect postgres -target-id ttcp_NJQ4NO87QJ -dbname northwind
psql (14.10 (Homebrew), server 13.13)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

northwind=> \conninfo
You are connected to database "northwind" as user "v-token-to-write-hcFLGfD40CeKPDpG4dSA-1707213290" on host "127.0.0.1" at port "59908".
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
northwind=> create database dbatest2;
ERROR:  permission denied to create database
northwind=> \l
                                                                       List of databases
   Name    |                     Owner                      | Encoding |   Collate   |    Ctype    |                     Access privileges   
-----------+------------------------------------------------+----------+-------------+-------------+-----------------------------------------------------------
 dbatest   | v-token-to-dba-wNVIPCDSDa1RNUeLajDv-1707202187 | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 northwind | demo                                           | UTF8     | en_US.UTF-8 | en_US.UTF-8 | demo=CTc/demo                                            +
           |                                                |          |             |             | "v-token-to-write-hcFLGfD40CeKPDpG4dSA-1707213290"=c/demo
 postgres  | demo                                           | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 rdsadmin  | rdsadmin                                       | UTF8     | en_US.UTF-8 | en_US.UTF-8 | rdsadmin=CTc/rdsadmin                                    +
           |                                                |          |             |             | rdstopmgr=Tc/rdsadmin
 template0 | rdsadmin                                       | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/rdsadmin                                              +
           |                                                |          |             |             | rdsadmin=CTc/rdsadmin
 template1 | demo                                           | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/demo                                                  +
           |                                                |          |             |             | demo=CTc/demo
(6 rows)

northwind=> CREATE TABLE "test2" ("fullName" varchar(255), "isUser" varchar(255), "rating" varchar(255));
ERROR:  permission denied for schema public
LINE 1: CREATE TABLE "test2" ("fullName" varchar(255), "isUser" varc...
                     ^
northwind=> INSERT INTO "test" ("fullName", "isUser", "rating") VALUES ('Katie Kildea', 'false', '⭐️⭐️'), ('Micah Bonass', 'true', '⭐️⭐️⭐️⭐️'), ('Brigid Whitsey', 'true', '⭐️⭐️');
INSERT 0 3
northwind=> select * from us_states;
 state_id |      state_name      | state_abbr | state_region 
----------+----------------------+------------+--------------
        1 | Alabama              | AL         | south
        2 | Alaska               | AK         | north
        3 | Arizona              | AZ         | west
        4 | Arkansas             | AR         | south
        5 | California           | CA         | west
        6 | Colorado             | CO         | west
        7 | Connecticut          | CT         | east
        8 | Delaware             | DE         | east
        9 | District of Columbia | DC         | east
       10 | Florida              | FL         | south
       11 | Georgia              | GA         | south
       12 | Hawaii               | HI         | west
       13 | Idaho                | ID         | midwest
       14 | Illinois             | IL         | midwest
       15 | Indiana              | IN         | midwest
       16 | Iowa                 | IO         | midwest
       17 | Kansas               | KS         | midwest
       18 | Kentucky             | KY         | south
       19 | Louisiana            | LA         | south
       20 | Maine                | ME         | north
       21 | Maryland             | MD         | east
       22 | Massachusetts        | MA         | north
       23 | Michigan             | MI         | north
       24 | Minnesota            | MN         | north
       25 | Mississippi          | MS         | south
       26 | Missouri             | MO         | south
       27 | Montana              | MT         | west
       28 | Nebraska             | NE         | midwest
       29 | Nevada               | NV         | west
       30 | New Hampshire        | NH         | east
       31 | New Jersey           | NJ         | east
       32 | New Mexico           | NM         | west
       33 | New York             | NY         | east
       34 | North Carolina       | NC         | east
       35 | North Dakota         | ND         | midwest
       36 | Ohio                 | OH         | midwest
       37 | Oklahoma             | OK         | midwest
       38 | Oregon               | OR         | west
       39 | Pennsylvania         | PA         | east
       40 | Rhode Island         | RI         | east
       41 | South Carolina       | SC         | east
       42 | South Dakota         | SD         | midwest
       43 | Tennessee            | TN         | midwest
       44 | Texas                | TX         | west
       45 | Utah                 | UT         | west
       46 | Vermont              | VT         | east
       47 | Virginia             | VA         | east
       48 | Washington           | WA         | west
       49 | West Virginia        | WV         | south
       50 | Wisconsin            | WI         | midwest
       51 | Wyoming              | WY         | west
(51 rows)

northwind=> select * from test;
    fullName    | isUser | rating 
----------------+--------+--------
 Almeda Shields | true   | ⭐️⭐️
 Daniele Upward | false  | ⭐️⭐️
 Katie Kildea   | false  | ⭐️⭐️
 Micah Bonass   | true   | ⭐️⭐️⭐️⭐️
 Brigid Whitsey | true   | ⭐️⭐️
(5 rows)
```

## RDS ReadOnly

```bash
> export BOUNDARY_ADDR=https://72a20d60-b9c3-438d-8664-dfcbaaaf0867.boundary.hashicorp.cloud

> boundary authenticate oidc -auth-method-id amoidc_l17XJAoZXb
Opening returned authentication URL in your browser...
https://dev-q6ml3431eugrpfdc.us.auth0.com/authorize?client_id=prJEtaNbo9NqHLf7tjKeDM5GWfmI6amc&max_age=0&nonce=gTGh7INtRzT0G2hPN1WY&redirect_uri=https%3A%...

Authentication information:
  Account ID:      acctoidc_pAmhCujkNE
  Auth Method ID:  amoidc_l17XJAoZXb
  Expiration Time: Tue, 13 Feb 2024 11:11:07 CET
  User ID:         u_h3xO0X79Og

The token name "default" was successfully stored in the chosen keyring and is not displayed here.

> boundary targets list -recursive

Target information:
  ID:                    ttcp_NyckluxxQp
    Scope ID:            p_MfRkfe58Bd
    Version:             3
    Type:                tcp
    Name:                RDS ReadOnly Access
    Description:         RDS: SELECT
    Authorized Actions:
      read
      authorize-session

  ID:                    ttcp_18raqgMmbq
    Scope ID:            p_MfRkfe58Bd
    Version:             3
    Type:                tcp
    Name:                DocumentDB ReadOnly Access
    Description:         DocumentDB: readAllDBs
    Authorized Actions:
      authorize-session
      read

> boundary connect postgres -target-id ttcp_NyckluxxQp -dbname northwind   
psql (14.10 (Homebrew), server 13.13)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

northwind=> \conninfo
You are connected to database "northwind" as user "v-token-to-readonly-pLqGwK7sOeRJIl35s0JG-1707214382" on host "127.0.0.1" at port "60227".
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
northwind=> CREATE TABLE "test3" ("fullName" varchar(255), "isUser" varchar(255), "rating" varchar(255));
ERROR:  permission denied for schema public
LINE 1: CREATE TABLE "test3" ("fullName" varchar(255), "isUser" varc...
                     ^
northwind=> INSERT INTO "test" ("fullName", "isUser", "rating") VALUES ('Katie Kildea', 'false', '⭐️⭐️'), ('Micah Bonass', 'true', '⭐️⭐️⭐️⭐️'), ('Brigid Whitsey', 'true', '⭐️⭐️');
ERROR:  permission denied for table test
northwind=> select * from us_states;
 state_id |      state_name      | state_abbr | state_region 
----------+----------------------+------------+--------------
        1 | Alabama              | AL         | south
        2 | Alaska               | AK         | north
        3 | Arizona              | AZ         | west
        4 | Arkansas             | AR         | south
        5 | California           | CA         | west
        6 | Colorado             | CO         | west
        7 | Connecticut          | CT         | east
        8 | Delaware             | DE         | east
        9 | District of Columbia | DC         | east
       10 | Florida              | FL         | south
       11 | Georgia              | GA         | south
       12 | Hawaii               | HI         | west
       13 | Idaho                | ID         | midwest
       14 | Illinois             | IL         | midwest
       15 | Indiana              | IN         | midwest
       16 | Iowa                 | IO         | midwest
       17 | Kansas               | KS         | midwest
       18 | Kentucky             | KY         | south
       19 | Louisiana            | LA         | south
       20 | Maine                | ME         | north
       21 | Maryland             | MD         | east
       22 | Massachusetts        | MA         | north
       23 | Michigan             | MI         | north
       24 | Minnesota            | MN         | north
       25 | Mississippi          | MS         | south
       26 | Missouri             | MO         | south
       27 | Montana              | MT         | west
       28 | Nebraska             | NE         | midwest
       29 | Nevada               | NV         | west
       30 | New Hampshire        | NH         | east
       31 | New Jersey           | NJ         | east
       32 | New Mexico           | NM         | west
       33 | New York             | NY         | east
       34 | North Carolina       | NC         | east
       35 | North Dakota         | ND         | midwest
       36 | Ohio                 | OH         | midwest
       37 | Oklahoma             | OK         | midwest
       38 | Oregon               | OR         | west
       39 | Pennsylvania         | PA         | east
       40 | Rhode Island         | RI         | east
       41 | South Carolina       | SC         | east
       42 | South Dakota         | SD         | midwest
       43 | Tennessee            | TN         | midwest
       44 | Texas                | TX         | west
       45 | Utah                 | UT         | west
       46 | Vermont              | VT         | east
       47 | Virginia             | VA         | east
       48 | Washington           | WA         | west
       49 | West Virginia        | WV         | south
       50 | Wisconsin            | WI         | midwest
       51 | Wyoming              | WY         | west
(51 rows)


northwind=> select * from test;
    fullName    | isUser | rating 
----------------+--------+--------
 Almeda Shields | true   | ⭐️⭐️
 Daniele Upward | false  | ⭐️⭐️
 Katie Kildea   | false  | ⭐️⭐️
 Micah Bonass   | true   | ⭐️⭐️⭐️⭐️
 Brigid Whitsey | true   | ⭐️⭐️
(5 rows)
```

## DocumentDB DBA

```sql_more
> export BOUNDARY_ADDR=https://7d018f9c-ee36-4ac4-90b6-10b465770d5c.boundary.hashicorp.cloud
> boundary authenticate oidc -auth-method-id amoidc_kFalRmMWZw
Opening returned authentication URL in your browser...
https://dev-q6ml3431eugrpfdc.us.auth0.com/authorize?client_id=OHgDoLbq0K4H71o51CumJ2QtpYi6asF6&max_age=0&nonce=CV3vDQ7FIDJZPdCHRBMw&redirect_uri=https%3A%2F%2F7d018f9c-ee36-4ac4-90b6-10b465770d5c.boundary.hashicorp.cloud%2Fv1%2Fauth-methods%2Foidc%3Aauthenticate%3Acallback&response_type=code&scope=openid&state=NFSM7Lhse1G7kKVVzF3UHanpwUraXzyc367zZrMRr3K3jmAv5oQinNXkBZvDiC8H1wCBWkuk1Ekw8LjF3drJB9gbg8ZQpTqixQMAfsLfGQuz63ETR1qSFcH6PRMqfA1iDLnaSbDyzQVR4WpRc7g4EoMet1Di41QSeMwYknKfUzD9upicPJkUkMHCEFrnR5c6eUvqEEwVMJ2ph1NTAV7jfTMnxMrwuUYWVXUgSeNc4LjBKmxGsHwMujizBJ7e1EXeY9L14FsuBWYu9B8JPEwyEHpz3rPnvkgL1cVAsZLLbMSSiDzwM1gGBJFyqpjG5bBDCMCPDyaXBwHf7eLu26ctRGS38Pc8XeYesGBVNnfEXjMJfcoZXB5fjLLGR53yapBBADguegYu2P9bXzzRJCqvUtpyyQQ1iPDW6XMoExmNTypDvyjPc9CLjW1eFUPQjQpkTtBg

Authentication information:
  Account ID:      acctoidc_0eWZg22j0a
  Auth Method ID:  amoidc_kFalRmMWZw
  Expiration Time: Thu, 22 Feb 2024 09:06:10 CET
  User ID:         u_3x6ierNAGn

The token name "default" was successfully stored in the chosen keyring and is not displayed here.

> boundary targets list -recursive

Target information:
  ID:                    ttcp_5KF7b2nemT
    Scope ID:            p_3qnPearCT1
    Version:             3
    Type:                tcp
    Name:                DocumentDB DBA Access
    Description:         DocumentDB: DBA Permissions
    Authorized Actions:
      authorize-session
      read

  ID:                    ttcp_UflbyKyPWb
    Scope ID:            p_3qnPearCT1
    Version:             3
    Type:                tcp
    Name:                RDS DBA Access
    Description:         RDS DBA Permissions
    Authorized Actions:
      read
      authorize-session

eval "$(boundary targets authorize-session -id ttcp_5KF7b2nemT -format json | jq -r '.item | "export BOUNDARY_SESSION_TOKEN=\(.authorization_token) BOUNDARY_SESSION_USERNAME=\(.credentials[0].secret.decoded.username) BOUNDARY_SESSION_PASSWORD=\(.credentials[0].secret.decoded.password)"')
> boundary connect -exec mongosh -authz-token=$BOUNDARY_SESSION_TOKEN --  --tls --host {{boundary.addr}} --username $BOUNDARY_SESSION_USERNAME --password $BOUNDARY_SESSION_PASSWORD --tlsAllowInvalidCertificates --retryWrites false

Proxy listening information:
  Address:             127.0.0.1
  Connection Limit:    3600
  Expiration:          Thu, 15 Feb 2024 17:11:05 CET
  Port:                58558
  Protocol:            tcp
  Session ID:          s_PK2t9h2KN5
Current Mongosh Log ID:	65cdc7297b18a74a9f2010b1
Connecting to:		mongodb://<credentials>@127.0.0.1:58558/?directConnection=true&serverSelectionTimeoutMS=2000&tls=true&tlsAllowInvalidCertificates=true&retryWrites=false&appName=mongosh+2.1.3
Using MongoDB:		5.0.0
Using Mongosh:		2.1.3
mongosh 2.1.4 is available for download: https://www.mongodb.com/try/download/shell

For mongosh info see: https://docs.mongodb.com/mongodb-shell/

rs0 [direct: primary] test> db.runCommand({connectionStatus : 1})
{
  authInfo: {
    authenticatedUsers: [
      {
        user: 'v-token-token-dba-9NB04Eptj9j8J2z2UeJZ-1707244196',
        db: 'admin'
      }
    ],
    authenticatedUserRoles: [
      { role: 'dbAdminAnyDatabase', db: 'admin' },
      { role: 'readWriteAnyDatabase', db: 'admin' },
      { role: 'userAdminAnyDatabase', db: 'admin' }
    ]
  },
  ok: 1,
  operationTime: Timestamp({ t: 1707244136, i: 1 })
}

rs0 [direct: primary] testdb> use mydatabase
switched to db mydatabase
rs0 [direct: primary] mydatabase> 

rs0 [direct: primary] mydatabase> db.createCollection("mycollection")
{ ok: 1 }
rs0 [direct: primary] mydatabase> db.mycollection.insertOne({
   name: 'John Doe',
   age: 30,
   city: 'New York'
})
{
  acknowledged: true,
  insertedId: ObjectId('65c27da614fec5f6b5dedcff')
}
rs0 [direct: primary] mydatabase> db.mycollection.find()
[
  {
    _id: ObjectId('65c27da614fec5f6b5dedcff'),
    name: 'John Doe',
    age: 30,
    city: 'New York'
  }
]
rs0 [direct: primary] mydatabase> db.mycollection.drop()
true
rs0 [direct: primary] mydatabase> db.dropDatabase()
{ ok: 1, dropped: 'mydatabase' }
rs0 [direct: primary] mydatabase> use test
switched to db test
rs0 [direct: primary] test> db.getUsers()
{
  ok: 1,
  users: [
    {
      _id: 'serviceadmin',
      user: 'serviceadmin',
      db: 'admin',
      roles: [ { db: 'admin', role: 'root' } ]
    },
    {
      _id: 'demo',
      user: 'demo',
      db: 'admin',
      roles: [ { db: 'admin', role: 'root' } ]
    },
    {
      _id: 'v-token-token-dba-9NB04Eptj9j8J2z2UeJZ-1707244196',
      user: 'v-token-token-dba-9NB04Eptj9j8J2z2UeJZ-1707244196',
      db: 'admin',
      roles: [
        { db: 'admin', role: 'userAdminAnyDatabase' },
        { db: 'admin', role: 'dbAdminAnyDatabase' },
        { db: 'admin', role: 'readWriteAnyDatabase' }
      ]
    }
  ],
  operationTime: Timestamp({ t: 1707245099, i: 1 })
}
```

## DocumentDB ReadWrite

```sql_more
> export BOUNDARY_ADDR=https://7d018f9c-ee36-4ac4-90b6-10b465770d5c.boundary.hashicorp.cloud
> boundary authenticate oidc -auth-method-id amoidc_kFalRmMWZw
Opening returned authentication URL in your browser...
https://dev-q6ml3431eugrpfdc.us.auth0.com/authorize?client_id=OHgDoLbq0K4H71o51CumJ2QtpYi6asF6&max_age=0&nonce=7OSh6XM77W0r052Aomoa&redirect_uri=https%3A%2F%2F7d018f9c-ee36-4ac4-90b6-10b465770d5c.boundary.hashicorp.cloud%2Fv1%2Fauth-methods%2Foidc%3Aauthenticate%3Acallback&response_type=code&scope=openid&state=NFSM7Lhse1G7kKVVzF3UHanpwUraXzyc367zZrMRr3K3jmAv5oQinNXkBZvDiC8H1wCBWkuk1Ekw8LjF3drJB9gbg8ZQpTqixQMAfsLfGQuz63ETR1qSFcH6KoQVkuiWLpHytjpw6a9pBUj2AH94qkv2R3tHVsS8faPTccBvbZheZHPc2kvYpQpahd5kiUz2DYSrHfBSGkNDfg3WD7sBqx1ab8riLDzviA8Pa7HxgzN8d12BEM6YX6CQuq6oxQfBXdyb1D9MAdokuFaod1R6UdivBVNRSNaGaKtpfwzJ7ZRJMuT9zCChyjNzV6JU9yko6ERXaKpqY9DVk2KAY5oxCWAgWza4LWk59XYav5LzBQdrC8gLTFUJzLTd9eMSX2f2n4qBcC6GgYZ7z97FpdR6w3y3WiHWKznvinkLTLj9BTBJwHm9fG6UFbjKScp5LK8KbM98

Authentication information:
  Account ID:      acctoidc_gfwbHESwrq
  Auth Method ID:  amoidc_kFalRmMWZw
  Expiration Time: Thu, 22 Feb 2024 09:32:53 CET
  User ID:         u_5WmplVDem2

The token name "default" was successfully stored in the chosen keyring and is not displayed here.
> boundary targets list -recursive

Target information:
  ID:                    ttcp_ezWrfC1F8h
    Scope ID:            p_3qnPearCT1
    Version:             3
    Type:                tcp
    Name:                RDS Read/Write Access
    Description:         RDS: SELECT, INSERT, UPDATE, DELETE
    Authorized Actions:
      read
      authorize-session

  ID:                    ttcp_AV0272rFCb
    Scope ID:            p_3qnPearCT1
    Version:             3
    Type:                tcp
    Name:                DocumentDB Read/Write Access
    Description:         DocumentDB: readWriteAllDBs
    Authorized Actions:
      authorize-session
      read

> eval "$(boundary targets authorize-session -id ttcp_AV0272rFCb -format json | jq -r '.item | "export BOUNDARY_SESSION_TOKEN=\(.authorization_token) BOUNDARY_SESSION_USERNAME=\(.credentials[0].secret.decoded.username) BOUNDARY_SESSION_PASSWORD=\(.credentials[0].secret.decoded.password)"')"
boundary connect -exec mongosh -authz-token=$BOUNDARY_SESSION_TOKEN --  --tls --host {{boundary.addr}} --username $BOUNDARY_SESSION_USERNAME --password $BOUNDARY_SESSION_PASSWORD --tlsAllowInvalidCertificates --retryWrites false

Proxy listening information:
  Address:             127.0.0.1
  Connection Limit:    3600
  Expiration:          Thu, 15 Feb 2024 17:33:58 CET
  Port:                58931
  Protocol:            tcp
  Session ID:          s_VJlsI25TKo
Current Mongosh Log ID:	65cdcc770e4edc0a8dd1ddb7
Connecting to:		mongodb://<credentials>@127.0.0.1:58931/?directConnection=true&serverSelectionTimeoutMS=2000&tls=true&tlsAllowInvalidCertificates=true&retryWrites=false&appName=mongosh+2.1.3
Using MongoDB:		5.0.0
Using Mongosh:		2.1.3
mongosh 2.1.4 is available for download: https://www.mongodb.com/try/download/shell

For mongosh info see: https://docs.mongodb.com/mongodb-shell/

rs0 [direct: primary] test> db.runCommand({connectionStatus : 1})
{
  authInfo: {
    authenticatedUsers: [
      {
        user: 'v-token-token-read_write-7fvTfU6B4kUh9acVkilx-1707287236',
        db: 'admin'
      }
    ],
    authenticatedUserRoles: [ { role: 'readWriteAnyDatabase', db: 'admin' } ]
  },
  ok: 1,
  operationTime: Timestamp({ t: 1707287426, i: 1 })
}
rs0 [direct: primary] test> use mydatabase2
switched to db mydatabase2
rs0 [direct: primary] mydatabase2> db.createCollection("mycollection2")
{ ok: 1 }
rs0 [direct: primary] mydatabase2> db.mycollection2.insertOne({
    name: 'John Doe',
    age: 30,
    city: 'New York'
})
{
  acknowledged: true,
  insertedId: ObjectId('65c323da6f5259b2e84bf429')
}
rs0 [direct: primary] mydatabase2> db.mycollection.find()
[
  {
    _id: ObjectId('65c323da6f5259b2e84bf429'),
    name: 'John Doe',
    age: 30,
    city: 'New York'
  }
]
rs0 [direct: primary] mydatabase2> db.mycollection.drop()
true
rs0 [direct: primary] mydatabase2> db.dropDatabase()
MongoServerError: Authorization failure
rs0 [direct: primary] mydatabase2> use test
switched to db test
rs0 [direct: primary] test> db.getUsers()
MongoServerError: Authorization failure
```

## DocumentDB ReadOnly

```sql_more
> export BOUNDARY_ADDR=https://7d018f9c-ee36-4ac4-90b6-10b465770d5c.boundary.hashicorp.cloud
> boundary authenticate oidc -auth-method-id amoidc_kFalRmMWZw
Opening returned authentication URL in your browser...
https://dev-q6ml3431eugrpfdc.us.auth0.com/authorize?client_id=OHgDoLbq0K4H71o51CumJ2QtpYi6asF6&max_age=0&nonce=Ir8lkiMGnYvH8qdAxQ3G&redirect_uri=https%3A%2F%2F7d018f9c-ee36-4ac4-90b6-10b465770d5c.boundary.hashicorp.cloud%2Fv1%2Fauth-methods%2Foidc%3Aauthenticate%3Acallback&response_type=code&scope=openid&state=NFSM7Lhse1G7kKVVzF3UHanpwUraXzyc367zZrMRr3K3jmAv5oQinNXkBZvDiC8H1wCBWkuk1Ekw8LjF3drJB9gbg8ZQpTqixQMAfsLfGQuz63ETR1qSFcH6Y5bB6kipx2DGf2YSwARq3moiPKMpHLCTb8xaV3D4GCS1bETL6rKBY65Zdk6HcKvpEccpGF4V2jTQY5RFVSTTattGPEvuy1nDkaqnYFufj67VYgbCXLTo5JQhBcTVeeo5msrL4UAHiyNp4rGbqNLuU4UyaF6LGLYvUYbDxBmb9JmEod1gjgv3T6QVV35PmusXyhYWjZ1UJSHyyEhjETDrwpgXCcokghSYEb2VBuW1LbFjXTgCy9gdazkC2kYMdSCLGTD5z9V4TdrgCUhk9tkYCaHtABFb9mAmNV7f9vgf4xV1a5C4ipVvr7rKDeBawRc9wHYcfCfhBGDL

Authentication information:
  Account ID:      acctoidc_dXQcGlVZXS
  Auth Method ID:  amoidc_kFalRmMWZw
  Expiration Time: Thu, 22 Feb 2024 09:36:11 CET
  User ID:         u_X93PKT600F

The token name "default" was successfully stored in the chosen keyring and is not displayed here.

> boundary targets list -recursive

Target information:
  ID:                    ttcp_cmdRTvMpOX
    Scope ID:            p_3qnPearCT1
    Version:             3
    Type:                tcp
    Name:                DocumentDB ReadOnly Access
    Description:         DocumentDB: readAllDBs
    Authorized Actions:
      read
      authorize-session

  ID:                    ttcp_y5a14LzaOT
    Scope ID:            p_3qnPearCT1
    Version:             3
    Type:                tcp
    Name:                RDS ReadOnly Access
    Description:         RDS: SELECT
    Authorized Actions:
      read
      authorize-session

> eval "$(boundary targets authorize-session -id ttcp_cmdRTvMpOX -format json | jq -r '.item | "export BOUNDARY_SESSION_TOKEN=\(.authorization_token) BOUNDARY_SESSION_USERNAME=\(.credentials[0].secret.decoded.username) BOUNDARY_SESSION_PASSWORD=\(.credentials[0].secret.decoded.password)"')"
boundary connect -exec mongosh -authz-token=$BOUNDARY_SESSION_TOKEN --  --tls --host {{boundary.addr}} --username $BOUNDARY_SESSION_USERNAME --password $BOUNDARY_SESSION_PASSWORD --tlsAllowInvalidCertificates --retryWrites false


rs0 [direct: primary] test> db.runCommand({connectionStatus : 1})
{
  authInfo: {
    authenticatedUsers: [
      {
        user: 'v-token-token-read_only-Tpyaf33LpBFFHesRysey-1707287972',
        db: 'admin'
      }
    ],
    authenticatedUserRoles: [ { role: 'readAnyDatabase', db: 'admin' } ]
  },
  ok: 1,
  operationTime: Timestamp({ t: 1707288068, i: 1 })
}
rs0 [direct: primary] test> use mydatabase3
switched to db mydatabase3
rs0 [direct: primary] mydatabase3> db.createCollection("mycollection3")
MongoServerError: Authorization failure
rs0 [direct: primary] mydatabase3> use mydatabase2
switched to db mydatabase2
rs0 [direct: primary] mydatabase2> db.mycollection.insertOne({
...     name: 'John Doe',
...     age: 30,
...     city: 'New York'
... })
MongoServerError: Authorization failure

rs0 [direct: primary] mydatabase2> db.runCommand(
...    {
...        listCollections: 1.0,
...        authorizedCollections: true,
...        nameOnly: true
...    }
... )
{
  waitedMS: Long('0'),
  cursor: {
    firstBatch: [ { name: 'mycollection2', type: 'collection' } ],
    id: Long('0'),
    ns: 'mydatabase2.$cmd.listCollections'
  },
  ok: 1,
  operationTime: Timestamp({ t: 1707288297, i: 1 })
}

rs0 [direct: primary] mydatabase2> db.mycollection2.find()
[
  {
    _id: ObjectId('65c327e8feed21cc028b8bd7'),
    name: 'John Doe',
    age: 30,
    city: 'New York'
  }
]
rs0 [direct: primary] mydatabase2> db.mycollection2.drop()
MongoServerError: Authorization failure
rs0 [direct: primary] mydatabase2> db.dropDatabase()
MongoServerError: Authorization failure
rs0 [direct: primary] mydatabase2> db.getUsers()
MongoServerError: Authorization failure
rs0 [direct: primary] mydatabase2> exit
```

# Clean Up

```bash
terraform destroy -auto-approve
cd ../2_Config/
vault lease revoke -force -prefix database && vault lease revoke -force -prefix mongo && terraform destroy -auto-approve && rm -rf cert.pem
cd ../1_Platform
terraform destroy -auto-approve
```
