output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
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
  value = try("http://${aws_lb.api["prod"].dns_name}${var.internal_alb_listener_port == 80 ? "" : ":${var.internal_alb_listener_port}"}", null)
}

output "api_alb_dns_name" {
  value = try(aws_lb.api["prod"].dns_name, null)
}
