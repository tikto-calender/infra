output "vpc_id" {
  value = module.network.vpc_id
}

output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "repository_urls" {
  value = module.ecr.repository_urls
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_build_role_arn" {
  value = module.github_build_role.arn
}

output "github_terraform_plan_role_arn" {
  value       = module.github_terraform_plan_role.arn
  description = "Read-only GitHub OIDC role used by the Terraform plan workflow."
}
