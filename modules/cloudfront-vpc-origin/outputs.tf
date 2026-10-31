output "id" {
  value       = aws_cloudfront_vpc_origin.this.id
  description = "CloudFront VPC origin ID."
}

output "arn" {
  value       = aws_cloudfront_vpc_origin.this.arn
  description = "CloudFront VPC origin ARN."
}
