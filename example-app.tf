locals {
  example_app_fqdn = "example-app.${var.ingress_domain}"
}

# TODO re-evaluate replacing aws_acm_certificate/aws_acm_certificate_validation/aws_route53_record
#      with acm-controller et al to be alike the cert-manager/external-dns CRDs
#      when the following issues are addressed.
#      see https://github.com/aws-controllers-k8s/community/issues/1904
#      see https://github.com/aws-controllers-k8s/community/issues/482#issuecomment-755922462
#      see https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2509
#      see https://github.com/aws-controllers-k8s/acm-controller/blob/v0.0.14/apis/v1alpha1/certificate.go#L23-L24

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
resource "aws_acm_certificate" "example_app" {
  domain_name       = local.example_app_fqdn
  validation_method = "DNS"
  key_algorithm     = "EC_prime256v1"
  lifecycle {
    create_before_destroy = true
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation
resource "aws_acm_certificate_validation" "example_app" {
  certificate_arn         = aws_acm_certificate.example_app.arn
  validation_record_fqdns = [for record in aws_route53_record.example_app_certificate_validation : record.fqdn]
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "example_app_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.example_app.domain_validation_options : dvo.domain_name => {
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
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#ingress-v1-networking-k8s-io
# see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/annotations/
# see https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1
resource "kubernetes_ingress_v1" "example_app" {
  metadata {
    name = "example-app"
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
      host = local.example_app_fqdn
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "example-app"
              port {
                name = "web"
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

# see https://kubernetes.io/docs/concepts/services-networking/service/#clusterip
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#service-v1-core
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#serviceport-v1-core
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1
# see https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/service/annotations/
# NB this creates a AWS Network Load Balancer (NLB).
resource "kubernetes_service_v1" "example_app" {
  metadata {
    name = "example-app"
  }
  spec {
    type = "ClusterIP"
    selector = {
      app = "example-app"
    }
    port {
      name        = "web"
      port        = 80
      protocol    = "TCP"
      target_port = "web"
    }
  }
  depends_on = [
    null_resource.eks,
  ]
}

# see https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#deployment-v1-apps
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#podtemplatespec-v1-core
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#container-v1-core
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment_v1
resource "kubernetes_deployment_v1" "example_app" {
  metadata {
    name = "example-app"
    labels = {
      app = "example-app"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "example-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "example-app"
        }
      }
      spec {
        enable_service_links = false
        container {
          name  = "example-app"
          image = local.images.example-app
          args = [
            "-listen=0.0.0.0:9000"
          ]
          # see https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/
          # see https://github.com/kubernetes/kubernetes/blob/v1.30.0/test/e2e/common/node/downwardapi.go
          env {
            name = "EXAMPLE_NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          env {
            name = "EXAMPLE_POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name = "EXAMPLE_POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name = "EXAMPLE_POD_UID"
            value_from {
              field_ref {
                field_path = "metadata.uid"
              }
            }
          }
          env {
            name = "EXAMPLE_POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
          port {
            name           = "web"
            container_port = 9000
          }
          resources {
            requests = {
              cpu    = "0.1"
              memory = "20Mi"
            }
            limits = {
              cpu    = "0.1"
              memory = "20Mi"
            }
          }
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
            run_as_non_root           = true
            seccomp_profile {
              type = "RuntimeDefault"
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
