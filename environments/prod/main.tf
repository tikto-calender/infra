locals {
  name         = "${var.project_name}-prod"
  cluster_name = "${local.name}-eks"
}

data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket_name
    key    = var.shared_state_key
    region = var.aws_region
  }
}

module "database" {
  source = "../../modules/dynamodb"

  name                   = "${local.name}-app"
  point_in_time_recovery = true
  deletion_protection    = true
}

module "eks" {
  source = "../../modules/eks-platform"

  name                        = local.cluster_name
  kubernetes_version          = var.kubernetes_version
  private_subnet_ids          = data.terraform_remote_state.shared.outputs.private_subnet_ids
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  node_instance_types         = var.node_instance_types
  node_capacity_type          = var.node_capacity_type
  node_min_size               = var.node_min_size
  node_desired_size           = var.node_desired_size
  node_max_size               = var.node_max_size
  dynamodb_table_arn          = module.database.arn
  application_namespace       = "tikto-prod"
  application_service_account = "tikto-app"
  log_retention_days          = 30
  enable_secrets_encryption   = true
}

module "observability" {
  source = "../../modules/eks-observability"

  cluster_name       = module.eks.cluster_name
  log_retention_days = 30
  alarm_actions      = var.monitoring_alarm_actions

  depends_on = [module.eks]
}

data "aws_lb" "api" {
  count = var.enable_edge ? 1 : 0

  name = var.internal_alb_name
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.enable_edge ? 1 : 0

  name = "com.amazonaws.global.cloudfront.origin-facing"
}

check "edge_configuration" {
  assert {
    condition     = !var.enable_edge || var.frontend_bucket_name != null
    error_message = "frontend_bucket_name is required when enable_edge is true."
  }
}

check "api_origin_is_private_alb" {
  assert {
    condition = !var.enable_edge || try(
      data.aws_lb.api[0].internal && data.aws_lb.api[0].load_balancer_type == "application",
      false
    )
    error_message = "The production edge requires the internal application load balancer created by GitOps."
  }
}

resource "aws_vpc_security_group_ingress_rule" "cloudfront_to_alb" {
  for_each = var.enable_edge ? toset(data.aws_lb.api[0].security_groups) : toset([])

  security_group_id = each.value
  description       = "CloudFront origin-facing traffic to the private API ALB"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront[0].id
  from_port         = var.internal_alb_listener_port
  to_port           = var.internal_alb_listener_port
  ip_protocol       = "tcp"
}

module "vpc_origin" {
  count  = var.enable_edge ? 1 : 0
  source = "../../modules/cloudfront-vpc-origin"

  name                   = "${local.name}-api"
  origin_arn             = data.aws_lb.api[0].arn
  http_port              = var.internal_alb_listener_port
  https_port             = 443
  origin_protocol_policy = "http-only"

  depends_on = [aws_vpc_security_group_ingress_rule.cloudfront_to_alb]
}

module "edge" {
  count  = var.enable_edge ? 1 : 0
  source = "../../modules/frontend-edge"

  name                 = local.name
  bucket_name          = var.frontend_bucket_name
  force_destroy_bucket = false
  aliases              = var.frontend_aliases
  acm_certificate_arn  = var.frontend_acm_certificate_arn
  route53_zone_id      = var.frontend_route53_zone_id
  web_acl_id           = var.web_acl_id

  api_origin = {
    domain_name            = data.aws_lb.api[0].dns_name
    type                   = "vpc"
    vpc_origin_id          = module.vpc_origin[0].id
    http_port              = var.internal_alb_listener_port
    https_port             = 443
    origin_protocol_policy = "http-only"
  }
}
