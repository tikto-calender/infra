output "repository_urls" {
  value       = { for name, repository in aws_ecr_repository.this : name => repository.repository_url }
  description = "ECR repository URLs keyed by repository name."
}

output "repository_arns" {
  value       = { for name, repository in aws_ecr_repository.this : name => repository.arn }
  description = "ECR repository ARNs keyed by repository name."
}
