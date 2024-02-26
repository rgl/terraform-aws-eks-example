# get the available locations with: aws ec2 describe-regions | jq -r '.Regions[].RegionName' | sort
variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "aws-eks-example"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+$", var.project))
    error_message = "Invalid project."
  }
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "Invalid environment."
  }
}

variable "cluster_version" {
  type        = string
  description = "EKS cluster version. See https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html."
  default     = "1.29"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.cluster_version))
    error_message = "Invalid version. Please provide a MAJOR.MINOR version."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "Defines the CIDR block used on Amazon VPC created for Amazon EKS."
  default     = "10.42.0.0/16"
  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "Invalid CIDR block format. Please provide a valid CIDR block."
  }
}
