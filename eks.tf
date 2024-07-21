locals {
  cluster_name = "${var.project}-${var.environment}"
}

# the kubernetes cluster.
# see https://registry.terraform.io/modules/terraform-aws-modules/eks/aws
# see https://github.com/terraform-aws-modules/terraform-aws-eks
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.20.0"

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
      # see https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v20.20.0/modules/eks-managed-node-group/main.tf#L354
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

  depends_on = [
    module.vpc,
  ]
}

# see https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
# see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/
# see https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/v2.7.1/helm/aws-load-balancer-controller/Chart.yaml
# see https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/v2.7.1/helm/aws-load-balancer-controller/values.yaml
# see https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/v2.7.1/helm/aws-load-balancer-controller
# see https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/tag/v2.7.1
# see https://github.com/kubernetes-sigs/aws-load-balancer-controller/
# see https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/releases/tag/v1.16.3
# see https://github.com/aws-ia/terraform-aws-eks-blueprints-addons
module "eks_aws_load_balancer_controller" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true

  aws_load_balancer_controller = {
    wait                 = true
    role_name            = "${module.eks.cluster_name}-aws-load-balancer-controller-irsa"
    role_name_use_prefix = false
    values = [jsonencode({
      replicaCount = 1,
      ingressClassConfig = {
        default = true
      }
    })]
  }

  depends_on = [
    module.eks,
  ]
}
