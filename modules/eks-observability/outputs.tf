output "cloudwatch_agent_role_arn" {
  value       = aws_iam_role.adot.arn
  description = "Pod Identity role for the CloudWatch Observability add-on."
}

output "application_log_group" {
  value       = aws_cloudwatch_log_group.application.name
  description = "CloudWatch log group for application logs."
}

output "performance_log_group" {
  value       = aws_cloudwatch_log_group.performance.name
  description = "CloudWatch log group used by Container Insights."
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.eks.dashboard_name
  description = "CloudWatch dashboard name."
}
