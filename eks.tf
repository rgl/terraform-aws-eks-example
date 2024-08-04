locals {
  cluster_name = "${var.project}-${var.environment}"

  # see https://github.com/cert-manager/trust-manager
  # see https://artifacthub.io/packages/helm/cert-manager/trust-manager
  # renovate: datasource=helm depName=trust-manager registryUrl=https://charts.jetstack.io
  trust_manager_chart_version = "0.12.0"

  # see https://github.com/stakater/reloader
  # see https://artifacthub.io/packages/helm/stakater/reloader
  # renovate: datasource=helm depName=reloader registryUrl=https://stakater.github.io/stakater-charts
  reloader_chart_version = "1.0.119"
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone
resource "aws_route53_zone" "ingress" {
  name          = var.ingress_domain
  force_destroy = true
}

# overwrite the zone soa minimum ttl (aka nxdomain ttl) rr to use a lower ttl.
# NB the default soa rr minimum ttl is 86400 seconds (1 day).
# NB the default soa rr ttl is 900 seconds (15 minutes).
# NB the default soa rr value is <MNAME>. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400.
# NB the soa rr format is <MNAME> <RNAME> <SERIAL> <REFRESH> <RETRY> <EXPIRE> <MINIMUM>
#       MNAME:    primary master name server for this zone.
#       RNAME:    email address of the domain administrator (@ replaced with .).
#       SERIAL:   version number of the zone file, usually in yyyymmddnn format.
#       REFRESH:  seconds after which secondary name servers should query the master for the soa record.
#       RETRY:    seconds after which secondary name servers should retry if the last attempt failed.
#       EXPIRE:   seconds after which secondary name servers should stop answering requests if all refresh attempts failed.
#       MINIMUM:  the ttl value for negative caching (nxdomain responses).
# see https://datatracker.ietf.org/doc/html/rfc1035#section-3.3.13
# see https://datatracker.ietf.org/doc/html/rfc2308
# see https://datatracker.ietf.org/doc/html/rfc1912#section-2.2
# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "ingress_soa" {
  allow_overwrite = true
  zone_id         = aws_route53_zone.ingress.zone_id
  name            = aws_route53_zone.ingress.name
  type            = "SOA"
  records         = ["${aws_route53_zone.ingress.name_servers[0]}. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 600"]
  ttl             = 600 # 600 seconds (10 minutes).
}

# overwrite the zone ns rr ttl to use a lower ttl.
# NB the default ns rr ttl is 172800 seconds (2 days).
# see https://datatracker.ietf.org/doc/html/rfc1035#section-3.3.11
# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "ingress_ns" {
  allow_overwrite = true
  zone_id         = aws_route53_zone.ingress.zone_id
  name            = aws_route53_zone.ingress.name
  type            = "NS"
  records         = aws_route53_zone.ingress.name_servers
  ttl             = 600 # 600 seconds (10 minutes).
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

# see https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/releases/tag/v1.16.3
# see https://github.com/aws-ia/terraform-aws-eks-blueprints-addons
module "eks_aws_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # install external-dns.
  enable_external_dns = true
  external_dns_route53_zone_arns = [
    aws_route53_zone.ingress.arn,
  ]

  # install cert-manager.
  enable_cert_manager = true
  cert_manager = {
    wait                 = true
    role_name            = "${module.eks.cluster_name}-cert-manager-irsa"
    role_name_use_prefix = false
    values = [jsonencode({
    })]
  }
  cert_manager_route53_hosted_zone_arns = [
    aws_route53_zone.ingress.arn,
  ]

  helm_releases = {
    # install trust-manager.
    # see https://cert-manager.io/docs/tutorials/getting-started-with-trust-manager/
    # see https://github.com/cert-manager/trust-manager
    # see https://github.com/golang/go/blob/go1.22.3/src/crypto/x509/root_linux.go
    # see https://artifacthub.io/packages/helm/cert-manager/trust-manager
    "trust-manager" = {
      namespace  = "cert-manager"
      repository = "https://charts.jetstack.io"
      chart      = "trust-manager"
      version    = local.trust_manager_chart_version
      values = [jsonencode({
        secretTargets = {
          enabled              = true
          authorizedSecretsAll = true
        }
      })]
    },

    # install reloader.
    # NB tls libraries typically load the certificates from ca-certificates.crt
    #    file once, when they are started, and they never reload the file again.
    #    reloader will automatically restart them when their configmap/secret
    #    changes.
    # see https://cert-manager.io/docs/tutorials/getting-started-with-trust-manager/
    # see https://github.com/stakater/reloader
    # see https://artifacthub.io/packages/helm/stakater/reloader
    # see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
    "reloader" = {
      namespace  = "kube-system"
      repository = "https://stakater.github.io/stakater-charts"
      chart      = "reloader"
      version    = local.reloader_chart_version
      values = [jsonencode({
        reloader = {
          autoReloadAll = false
        }
      })]
    },
  }

  depends_on = [
    module.eks,
    module.eks_aws_load_balancer_controller,
  ]
}

resource "null_resource" "eks" {
  depends_on = [
    module.eks,
    module.eks_aws_load_balancer_controller,
    module.eks_aws_addons,
  ]
}
