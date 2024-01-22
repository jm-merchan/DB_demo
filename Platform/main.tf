# Declare the required providers and their version constraints for this Terraform configuration
terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.8"
    }
    hcp = {
      source = "hashicorp/hcp"
      # version = "0.63.0"
      version = "0.66.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.7.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.1"
    }
  }
}
