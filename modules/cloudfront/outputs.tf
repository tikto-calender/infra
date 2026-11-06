output "bucket_name" {
  value       = aws_s3_bucket.frontend.id
  description = "Frontend deployment bucket."
}

output "distribution_id" {
  value       = aws_cloudfront_distribution.this.id
  description = "CloudFront distribution ID."
}

output "distribution_arn" {
  value       = aws_cloudfront_distribution.this.arn
  description = "CloudFront distribution ARN."
}

output "distribution_domain_name" {
  value       = aws_cloudfront_distribution.this.domain_name
  description = "CloudFront hostname."
}

output "application_url" {
  value       = "https://${length(var.aliases) > 0 ? var.aliases[0] : aws_cloudfront_distribution.this.domain_name}"
  description = "Primary application URL."
}
