output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = data.terraform_remote_state.shared.outputs.vpc_id
}

output "private_subnet_ids" {
  value = data.terraform_remote_state.shared.outputs.private_subnet_ids
}

output "dynamodb_table_name" {
  value = module.database.name
}

output "application_role_arn" {
  value = module.eks.application_role_arn
}

output "alb_controller_role_arn" {
  value = module.eks.alb_controller_role_arn
}

output "adot_role_arn" {
  value = module.observability.adot_role_arn
}

output "fluent_bit_role_arn" {
  value = module.observability.fluent_bit_role_arn
}

output "cloudwatch_dashboard_name" {
  value = module.observability.dashboard_name
}

output "application_url" {
  value = try(module.edge[0].application_url, null)
}

output "frontend_bucket_name" {
  value = try(module.edge[0].bucket_name, null)
}

output "cloudfront_distribution_id" {
  value = try(module.edge[0].distribution_id, null)
}

output "vpc_origin_id" {
  value = try(module.vpc_origin[0].id, null)
}

output "api_alb_dns_name" {
  value = try(data.aws_lb.api[0].dns_name, null)
}
