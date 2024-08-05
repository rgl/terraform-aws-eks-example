locals {
  argocd_fqdn = "argocd.${var.ingress_domain}"

  # see https://artifacthub.io/packages/helm/argo/argo-cd
  # see https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
  # renovate: datasource=helm depName=argo-cd registryUrl=https://argoproj.github.io/argo-helm
  argocd_chart_version = "7.3.11" # app version 2.11.7.

  # NB the default values are described at:
  #       https://github.com/argoproj/argo-helm/blob/argo-cd-7.3.11/charts/argo-cd/values.yaml
  #    NB make sure you are seeing the same version of the chart that you are installing.
  # NB this disables the tls between argocd components, that is, the internal
  #    cluster traffic does not uses tls, and only the ingress uses tls.
  #    see https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd#ssl-termination-at-ingress-controller
  #    see https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/#inbound-tls-options-for-argocd-server
  #    see https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/#disabling-tls-to-argocd-repo-server
  #    see https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/#disabling-tls-to-argocd-dex-server
  argocd_helm_values = {
    global = {
      domain = local.argocd_fqdn
    }
    configs = {
      params = {
        # disable tls between the argocd components.
        "server.insecure"                                = "true"
        "server.repo.server.plaintext"                   = "true"
        "server.dex.server.plaintext"                    = "true"
        "controller.repo.server.plaintext"               = "true"
        "applicationsetcontroller.repo.server.plaintext" = "true"
        "reposerver.disable.tls"                         = "true"
        "dexserver.disable.tls"                          = "true"
      }
    }
  }
}

# TODO re-evaluate replacing aws_acm_certificate/aws_acm_certificate_validation/aws_route53_record
#      with acm-controller et al to be alike the cert-manager/external-dns CRDs
#      when the following issues are addressed.
#      see https://github.com/aws-controllers-k8s/community/issues/1904
#      see https://github.com/aws-controllers-k8s/community/issues/482#issuecomment-755922462
#      see https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2509
#      see https://github.com/aws-controllers-k8s/acm-controller/blob/v0.0.14/apis/v1alpha1/certificate.go#L23-L24

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
resource "aws_acm_certificate" "argocd" {
  domain_name       = local.argocd_fqdn
  validation_method = "DNS"
  key_algorithm     = "EC_prime256v1"
  lifecycle {
    create_before_destroy = true
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation
resource "aws_acm_certificate_validation" "argocd" {
  certificate_arn         = aws_acm_certificate.argocd.arn
  validation_record_fqdns = [for record in aws_route53_record.argocd_certificate_validation : record.fqdn]
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "argocd_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.argocd.domain_validation_options : dvo.domain_name => {
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

# TODO figure out how to do this using the argocd helm values above.
# see https://kubernetes.io/docs/concepts/services-networking/ingress/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#ingress-v1-networking-k8s-io
# see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/annotations/
# see https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    namespace = "argocd"
    name      = "argocd"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/group.name"       = var.ingress_domain
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/ssl-policy"       = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
    }
  }
  spec {
    rule {
      host = local.argocd_fqdn
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argo-cd-argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    null_resource.eks,
  ]
}
