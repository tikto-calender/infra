resource "aws_cloudfront_vpc_origin" "this" {
  vpc_origin_endpoint_config {
    name                   = var.name
    arn                    = var.origin_arn
    http_port              = var.http_port
    https_port             = var.https_port
    origin_protocol_policy = var.origin_protocol_policy

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = merge(var.tags, {
    Name      = var.name
    ManagedBy = "Terraform"
    Module    = "cloudfront-vpc-origin"
  })

  timeouts {
    create = "20m"
    delete = "20m"
  }
}
