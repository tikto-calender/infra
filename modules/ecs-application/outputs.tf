output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "ECS cluster name."
}

output "backend_service_name" {
  value       = aws_ecs_service.backend.name
  description = "Backend ECS service name."
}

output "backend_service_arn" {
  value       = aws_ecs_service.backend.id
  description = "Backend ECS service ARN."
}

output "notification_service_name" {
  value       = aws_ecs_service.notification.name
  description = "Notification ECS service name."
}

output "notification_service_arn" {
  value       = aws_ecs_service.notification.id
  description = "Notification ECS service ARN."
}

output "alb_arn" {
  value       = aws_lb.api.arn
  description = "Development API ALB ARN."
}

output "alb_dns_name" {
  value       = aws_lb.api.dns_name
  description = "Development API ALB DNS name used as the CloudFront custom origin."
}

output "backend_task_role_arn" {
  value       = aws_iam_role.backend.arn
  description = "Backend task role ARN."
}

output "notification_task_role_arn" {
  value       = aws_iam_role.notification.arn
  description = "Notification task role ARN."
}

output "task_execution_role_arn" {
  value       = aws_iam_role.execution.arn
  description = "Shared ECS task execution role ARN."
}
