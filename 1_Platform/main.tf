# Declare the required providers and their version constraints for this Terraform configuration
terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.8"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.80.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.7.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.4"
    }
  }
}

provider "aws" {
  region = var.region
}

/* 
  It will ask for interactive login via browser 
  to obtain a token to operate with the API
*/

provider "hcp" {

}
