output "registry_region" {
  # e.g. 123456.dkr.ecr.eu-west-1.amazonaws.com/aws-eks-example/example
  #                     ^^^^^^^^^
  #                     region
  value = regex("^(?P<domain>[^/]+\\.ecr\\.(?P<region>[a-z0-9-]+)\\.amazonaws\\.com)", module.ecr_repository["example-app"].repository_url)["region"]
}

output "registry_domain" {
  # e.g. 123456.dkr.ecr.eu-west-1.amazonaws.com/aws-eks-example/example
  #      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #      domain
  value = regex("^(?P<domain>[^/]+\\.ecr\\.(?P<region>[a-z0-9-]+)\\.amazonaws\\.com)", module.ecr_repository["example-app"].repository_url)["domain"]
}

output "images" {
  # e.g. 123456.dkr.ecr.eu-west-1.amazonaws.com/aws-eks-example/example:1.2.3
  value = {
    for key, value in local.images : key => "${module.ecr_repository[key].repository_url}:${regex(":(?P<tag>[^:]+)$", value)["tag"]}"
  }
}

output "kubernetes_region" {
  value = var.region
}

output "kubernetes_cluster_name" {
  value = module.eks.cluster_name
}

output "kubernetes_oidc_issuer_url" {
  # e.g. https://oidc.eks.eu-west-1.amazonaws.com/id/DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
  value = module.eks.cluster_oidc_issuer_url
}

output "kubernetes_oidc_configuration_url" {
  # e.g. https://oidc.eks.eu-west-1.amazonaws.com/id/DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD/.well-known/openid-configuration
  value = "${module.eks.cluster_oidc_issuer_url}/.well-known/openid-configuration"
}

output "ingress_domain" {
  value = var.ingress_domain
}

output "ingress_domain_name_servers" {
  value = aws_route53_zone.ingress.name_servers
}

output "gitea_url" {
  value = "https://${local.gitea_fqdn}"
}

output "gitea_password" {
  value     = random_password.gitea.result
  sensitive = true
}

output "argocd_url" {
  value = "https://${local.argocd_fqdn}"
}

output "example_app_url" {
  value = "https://${local.example_app_fqdn}"
}
