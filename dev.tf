module "dev_database" {
  source = "./modules/dynamodb"

  name = "${var.project_name}-dev-eks-app"
}

# Keep the existing name and description for compatibility with earlier ALB state.
resource "aws_security_group" "dev_cloudfront_origin" {
  name        = "${var.project_name}-dev-eks-cloudfront-origin"
  description = "CloudFront access to the development EKS ALB"
  vpc_id      = module.network.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "dev_cloudfront_origin_to_vpc" {
  security_group_id = aws_security_group.dev_cloudfront_origin.id
  cidr_ipv4         = module.network.vpc_cidr
  ip_protocol       = "-1"
}

output "dev_application_url" {
  value = try("http://${aws_lb.api["dev"].dns_name}", null)
}

output "dev_dynamodb_table_name" {
  value = module.dev_database.name
}
