# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.7.0"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/aws
    # see https://github.com/hashicorp/terraform-provider-aws
    aws = {
      source  = "hashicorp/aws"
      version = "5.32.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/cloudinit
    # see https://github.com/hashicorp/terraform-provider-cloudinit
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }
    # see https://registry.terraform.io/providers/hashicorp/kubernetes
    # see https://github.com/hashicorp/terraform-provider-kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
    # see https://registry.terraform.io/providers/hashicorp/local
    # see https://github.com/hashicorp/terraform-provider-local
    local = {
      source  = "hashicorp/local"
      version = "2.4.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/time
    # see https://github.com/hashicorp/terraform-provider-time
    time = {
      source  = "hashicorp/time"
      version = "0.10.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/tls
    # see https://github.com/hashicorp/terraform-provider-tls
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "aws-eks-example"
      Environment = "test"
    }
  }
}
