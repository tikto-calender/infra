output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "EKS cluster name."
}

output "cluster_arn" {
  value       = aws_eks_cluster.this.arn
  description = "EKS cluster ARN."
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "Kubernetes API endpoint."
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  description = "Base64 cluster CA data."
  sensitive   = true
}

output "node_role_arn" {
  value       = aws_iam_role.nodes.arn
  description = "Managed node group IAM role."
}

output "application_role_arn" {
  value       = aws_iam_role.application.arn
  description = "Pod Identity role used by the application service account."
}

output "alb_controller_role_arn" {
  value       = aws_iam_role.alb_controller.arn
  description = "Pod Identity role used by AWS Load Balancer Controller."
}

output "external_secrets_role_arn" {
  value       = try(aws_iam_role.external_secrets[0].arn, null)
  description = "Pod Identity role used by External Secrets, or null when disabled."
}

