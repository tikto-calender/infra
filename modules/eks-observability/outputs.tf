output "adot_role_arn" {
  value       = aws_iam_role.adot.arn
  description = "Pod Identity role for the ADOT collector."
}

output "fluent_bit_role_arn" {
  value       = aws_iam_role.fluent_bit.arn
  description = "Pod Identity role for Fluent Bit."
}

output "application_log_group" {
  value       = aws_cloudwatch_log_group.application.name
  description = "CloudWatch log group used by Fluent Bit."
}

output "performance_log_group" {
  value       = aws_cloudwatch_log_group.performance.name
  description = "CloudWatch log group used by ADOT Container Insights."
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.eks.dashboard_name
  description = "CloudWatch dashboard name."
}
