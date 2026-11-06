output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "application_url" {
  value = module.edge.application_url
}

output "frontend_bucket_name" {
  value = module.edge.bucket_name
}

output "cloudfront_distribution_id" {
  value = module.edge.distribution_id
}

output "ecs_cluster_name" {
  value = module.application.cluster_name
}

output "backend_service_name" {
  value = module.application.backend_service_name
}

output "notification_service_name" {
  value = module.application.notification_service_name
}

output "api_alb_dns_name" {
  value = module.application.alb_dns_name
}

output "dynamodb_table_name" {
  value = module.database.name
}

output "github_deploy_role_arn" {
  value = module.github_deploy_role.arn
}
