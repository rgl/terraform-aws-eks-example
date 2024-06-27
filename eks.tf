locals {
  cluster_name = "${var.project}-${var.environment}"
}

# the kubernetes cluster.
# see https://registry.terraform.io/modules/terraform-aws-modules/eks/aws
# see https://github.com/terraform-aws-modules/terraform-aws-eks
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.4.0"

  cluster_name                   = local.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    # see https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html
    # see https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
    # see https://github.com/aws/amazon-vpc-cni-k8s
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          ENABLE_PREFIX_DELEGATION          = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
        enableNetworkPolicy = "true"
      })
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cluster_security_group = false
  create_node_security_group    = false

  authentication_mode = "API"

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      # use the bottlerocket os.
      # see https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami-bottlerocket.html
      # see https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html
      # see https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.14.0/modules/eks-managed-node-group/main.tf#L351
      ami_type = "BOTTLEROCKET_x86_64"

      instance_types = ["m5.large"]

      desired_size = 1
      min_size     = 1
      max_size     = 3

      update_config = {
        max_unavailable_percentage = 50
      }
    }
  }
}

# see https://registry.terraform.io/modules/hyperbadger/eks-kubeconfig/aws
# see https://github.com/hyperbadger/terraform-aws-eks-kubeconfig
module "eks-kubeconfig" {
  source       = "hyperbadger/eks-kubeconfig/aws"
  version      = "2.0.0"
  cluster_name = module.eks.cluster_name
  depends_on   = [module.eks]
}

resource "local_file" "kubeconfig" {
  filename        = "kubeconfig.yml"
  content         = module.eks-kubeconfig.kubeconfig
  file_permission = "0600"
}
