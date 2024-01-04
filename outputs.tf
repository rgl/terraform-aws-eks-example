output "registry_region" {
  # e.g. 123456.dkr.ecr.eu-west-1.amazonaws.com/aws-eks-example/example
  #                     ^^^^^^^^^
  #                     region
  value = regex("^(?P<domain>[^/]+\\.ecr\\.(?P<region>[a-z0-9-]+)\\.amazonaws\\.com)", module.ecr.repository_url)["region"]
}

output "registry_domain" {
  # e.g. 123456.dkr.ecr.eu-west-1.amazonaws.com/aws-eks-example/example
  #      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #      domain
  value = regex("^(?P<domain>[^/]+\\.ecr\\.(?P<region>[a-z0-9-]+)\\.amazonaws\\.com)", module.ecr.repository_url)["domain"]
}

output "example_repository_url" {
  # e.g. 123456.dkr.ecr.eu-west-1.amazonaws.com/aws-eks-example/example
  value = module.ecr.repository_url
}

output "kubernetes_oidc_issuer_url" {
  # e.g. https://oidc.eks.eu-west-1.amazonaws.com/id/DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
  value = module.eks.cluster_oidc_issuer_url
}

output "kubernetes_oidc_configuration_url" {
  # e.g. https://oidc.eks.eu-west-1.amazonaws.com/id/DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD/.well-known/openid-configuration
  value = "${module.eks.cluster_oidc_issuer_url}/.well-known/openid-configuration"
}
