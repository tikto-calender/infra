output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
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

output "cloudwatch_agent_role_arn" {
  value = module.observability.cloudwatch_agent_role_arn
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

output "github_frontend_deploy_role_arn" {
  value = try(module.github_frontend_deploy_role[0].arn, null)
}

output "api_alb_dns_name" {
  value = try(data.aws_lb.api[0].dns_name, null)
}

output "cloudfront_origin_security_group_id" {
  value       = aws_security_group.cloudfront_origin.id
  description = "Security group that the GitOps-managed public ALB must attach."
}

output "cloudfront_origin_security_group_name" {
  value       = aws_security_group.cloudfront_origin.name
  description = "Security group name accepted by the AWS Load Balancer Controller annotation."
}
