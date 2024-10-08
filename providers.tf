# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.9.5"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/aws
    # see https://github.com/hashicorp/terraform-provider-aws
    aws = {
      source  = "hashicorp/aws"
      version = "5.65.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/cloudinit
    # see https://github.com/hashicorp/terraform-provider-cloudinit
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.4"
    }
    # see https://registry.terraform.io/providers/hashicorp/helm
    # see https://github.com/hashicorp/terraform-provider-helm
    helm = {
      source  = "hashicorp/helm"
      version = "2.15.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/kubernetes
    # see https://github.com/hashicorp/terraform-provider-kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/local
    # see https://github.com/hashicorp/terraform-provider-local
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/null
    # see https://github.com/hashicorp/terraform-provider-null
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    # see https://registry.terraform.io/providers/hashicorp/random
    # see https://github.com/hashicorp/terraform-provider-random
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
    }
    # see https://registry.terraform.io/providers/hashicorp/time
    # see https://github.com/hashicorp/terraform-provider-time
    time = {
      source  = "hashicorp/time"
      version = "0.12.0"
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
      Project     = var.project
      Environment = var.environment
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
