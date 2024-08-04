locals {
  gitea_fqdn = "gitea.${var.ingress_domain}"

  # see https://artifacthub.io/packages/helm/gitea/gitea
  # renovate: datasource=helm depName=gitea registryUrl=https://dl.gitea.com/charts
  gitea_chart_version = "10.4.0" # app version: 1.22.1
}

# see https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
resource "random_password" "gitea" {
  length      = 16
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

# install gitea.
# NB the default values are described at:
#       https://gitea.com/gitea/helm-chart/src/tag/v10.4.0/values.yaml
#    NB make sure you are seeing the same version of the chart that you are installing.
resource "helm_release" "gitea" {
  namespace        = "gitea"
  name             = "gitea"
  repository       = "https://dl.gitea.com/charts"
  chart            = "gitea"
  version          = local.gitea_chart_version
  create_namespace = true
  values = [jsonencode({
    redis-cluster = {
      enabled = false
    }
    redis = {
      enabled = false
    }
    postgresql = {
      enabled = false
    }
    postgresql-ha = {
      enabled = false
    }
    persistence = {
      enabled      = true
      storageClass = "gp3"
      claimName    = "gitea"
      size         = "10Gi"
    }
    gitea = {
      config = {
        database = {
          DB_TYPE = "sqlite3"
        }
        session = {
          PROVIDER = "memory"
        }
        cache = {
          ADAPTER = "memory"
        }
        queue = {
          TYPE = "level"
        }
      }
      admin = {
        username = "gitea"
        password = random_password.gitea.result
      }
    }
    service = {
      http = {
        type      = "ClusterIP"
        port      = 3000
        clusterIP = null
      }
      ssh = {
        type      = "ClusterIP"
        port      = 22
        clusterIP = null
      }
    }
  })]
  depends_on = [
    null_resource.eks,
  ]
}

# TODO re-evaluate replacing aws_acm_certificate/aws_acm_certificate_validation/aws_route53_record
#      with acm-controller et al to be alike the cert-manager/external-dns CRDs
#      when the following issues are addressed.
#      see https://github.com/aws-controllers-k8s/community/issues/1904
#      see https://github.com/aws-controllers-k8s/community/issues/482#issuecomment-755922462
#      see https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2509
#      see https://github.com/aws-controllers-k8s/acm-controller/blob/v0.0.14/apis/v1alpha1/certificate.go#L23-L24

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
resource "aws_acm_certificate" "gitea" {
  domain_name       = local.gitea_fqdn
  validation_method = "DNS"
  key_algorithm     = "EC_prime256v1"
  lifecycle {
    create_before_destroy = true
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation
resource "aws_acm_certificate_validation" "gitea" {
  certificate_arn         = aws_acm_certificate.gitea.arn
  validation_record_fqdns = [for record in aws_route53_record.gitea_certificate_validation : record.fqdn]
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "gitea_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.gitea.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  type            = each.value.type
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  zone_id         = aws_route53_zone.ingress.zone_id
}

# see https://kubernetes.io/docs/concepts/services-networking/ingress/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#ingress-v1-networking-k8s-io
# see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/annotations/
# see https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1
resource "kubernetes_ingress_v1" "gitea" {
  metadata {
    namespace = "gitea"
    name      = "gitea"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/group.name"       = var.ingress_domain
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/ssl-policy"       = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
    }
  }
  spec {
    rule {
      host = local.gitea_fqdn
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "gitea-http"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.gitea,
  ]
}
