# a private container image repository.
# see https://registry.terraform.io/modules/terraform-aws-modules/ecr/aws
# see https://github.com/terraform-aws-modules/terraform-aws-ecr
module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "1.6.0"

  repository_type = "private"
  repository_name = var.example_repository_name

  repository_force_delete = true

  repository_image_scan_on_push = false

  create_lifecycle_policy = false
}
