This repo exists to help set up AWS for the purposes of Boundary integrations. It contains Terraform
code that can be used to spin up resources in AWS in order to help test Boundary features.

This repo assumes you have access to the `boundary_team_acctest_dev` account in doormat.
If you do not have access to this account please request access.

Once you have access,
1.  Clone this repo locally
1.  In [doormat](https://doormat.hashicorp.services/) click on the key on the "CLI" column on the `boundary_team_acctest_dev` row.
1.  Copy the button to "copy exporting AWS credentials to your clipboard"
1.  Paste it into your CLI
1.  Run `export AWS_REGION=us-east-1`
1.  Run `terraform init`
1.  Run `terraform apply` and enter yes
1.  Do what you need to do in boundary by following the info [here](https://github.com/hashicorp/boundary-plugin-host-aws)

For Dynamic Host Catalog resources...
1.  Get the iam access key ids and iam secret access keys by running the following commands:
    ```
    cat terraform.tfstate | jq .outputs.iam_access_key_ids.value
    cat terraform.tfstate | jq .outputs.iam_secret_access_keys.value
    ```
    The key id and the secret key are paired by index in the output array.

For Session Recording resources...
1. Get the bucket name, iam access key id, and iam secret access key by running the following commands:
    ```
    cat terraform.tfstate | jq .outputs.bucket_name.value
    cat terraform.tfstate | jq .outputs.storage_user_access_key_id.value
    cat terraform.tfstate | jq .outputs.storage_user_secret_access_key.value
    ```

When you are done...
1.  Run `terraform destroy` to bring down all the resources you brought up in AWS.
