output "arn" {
  value       = aws_iam_role.this.arn
  description = "GitHub Actions IAM role ARN."
}

output "name" {
  value       = aws_iam_role.this.name
  description = "GitHub Actions IAM role name."
}
