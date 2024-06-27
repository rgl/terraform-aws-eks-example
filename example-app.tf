# see https://kubernetes.io/docs/concepts/services-networking/service/#clusterip
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#service-v1-core
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#serviceport-v1-core
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1
resource "kubernetes_service_v1" "example_app" {
  metadata {
    name = "example-app"
  }
  spec {
    type = "LoadBalancer"
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
  depends_on = [module.eks]
}

# see https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#deployment-v1-apps
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#podtemplatespec-v1-core
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#container-v1-core
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
          # see https://github.com/kubernetes/kubernetes/blob/v1.29.2/test/e2e/common/node/downwardapi.go
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
  depends_on = [module.eks]
}
