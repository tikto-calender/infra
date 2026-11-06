locals {
  name = "${var.project_name}-prod"
}

data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket_name
    key    = var.shared_state_key
    region = var.terraform_state_region
  }
}

module "network" {
  source = "../modules/network"

  name                    = local.name
  vpc_cidr                = var.network.vpc_cidr
  availability_zones      = var.network.availability_zones
  public_subnet_cidrs     = var.network.public_subnet_cidrs
  private_subnet_cidrs    = var.network.private_subnet_cidrs
  nat_gateway_mode        = var.network.nat_gateway_mode
  map_public_ip_on_launch = var.map_public_ip_on_launch
  kubernetes_cluster_name = "${local.name}-eks"
}

module "database" {
  source = "../modules/dynamodb"

  name                   = "${local.name}-app"
  point_in_time_recovery = true
  deletion_protection    = true
}

module "eks" {
  source = "../modules/eks-platform"

  name                        = "${local.name}-eks"
  kubernetes_version          = var.kubernetes_version
  private_subnet_ids          = module.network.private_subnet_ids
  node_subnet_ids             = module.network.public_subnet_ids
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  node_instance_types         = var.node_instance_types
  node_capacity_type          = var.node_capacity_type
  node_min_size               = var.node_min_size
  node_desired_size           = var.node_desired_size
  node_max_size               = var.node_max_size
  dynamodb_table_arn          = module.database.arn
  application_namespace       = "tikto-prod"
  application_service_account = "tikto-app"
  log_retention_days          = var.log_retention_days
  enable_secrets_encryption   = true
}

module "observability" {
  source = "../modules/eks-observability"

  cluster_name       = module.eks.cluster_name
  log_retention_days = var.log_retention_days
  alarm_actions      = var.monitoring_alarm_actions

  depends_on = [module.eks]
}

data "aws_lb" "api" {
  count = var.enable_edge ? 1 : 0

  name = var.internal_alb_name

  lifecycle {
    postcondition {
      condition     = self.vpc_id == module.network.vpc_id
      error_message = "The production ALB must belong to the production VPC."
    }

    postcondition {
      condition     = !self.internal && self.load_balancer_type == "application"
      error_message = "The production edge requires an internet-facing Application Load Balancer."
    }

    postcondition {
      condition     = contains(self.security_groups, aws_security_group.cloudfront_origin.id)
      error_message = "The production ALB must use the Terraform-managed CloudFront origin security group."
    }
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "cloudfront_origin" {
  name = "${local.name}-cloudfront-origin"
  # Keep the existing description to avoid replacing an attached security group.
  description = "CloudFront access to the production internal ALB"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${local.name}-cloudfront-origin"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cloudfront_to_origin" {
  security_group_id = aws_security_group.cloudfront_origin.id
  description       = "HTTP from the CloudFront origin-facing managed prefix list"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  from_port         = var.internal_alb_listener_port
  to_port           = var.internal_alb_listener_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "cloudfront_origin_to_vpc" {
  security_group_id = aws_security_group.cloudfront_origin.id
  description       = "ALB traffic to targets inside the production VPC"
  cidr_ipv4         = module.network.vpc_cidr
  ip_protocol       = "-1"
}

check "edge_configuration" {
  assert {
    condition     = !var.enable_edge || var.frontend_bucket_name != null
    error_message = "frontend_bucket_name is required when enable_edge is true."
  }
}

module "edge" {
  count  = var.enable_edge ? 1 : 0
  source = "../modules/cloudfront"

  name                 = local.name
  bucket_name          = var.frontend_bucket_name
  force_destroy_bucket = false
  aliases              = var.frontend_aliases
  acm_certificate_arn  = var.frontend_acm_certificate_arn
  route53_zone_id      = var.frontend_route53_zone_id
  web_acl_id           = var.web_acl_id

  api_origin = {
    domain_name            = data.aws_lb.api[0].dns_name
    type                   = "custom"
    http_port              = var.internal_alb_listener_port
    https_port             = 443
    origin_protocol_policy = "http-only"
  }
}

data "aws_iam_policy_document" "github_frontend_deploy" {
  count = var.enable_edge ? 1 : 0

  statement {
    sid = "DeployFrontend"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${module.edge[0].bucket_name}",
      "arn:aws:s3:::${module.edge[0].bucket_name}/*"
    ]
  }

  statement {
    sid       = "InvalidateFrontend"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [module.edge[0].distribution_arn]
  }
}

module "github_frontend_deploy_role" {
  count  = var.enable_edge ? 1 : 0
  source = "../modules/github-oidc-role"

  name              = "${local.name}-github-frontend-deploy"
  oidc_provider_arn = data.terraform_remote_state.shared.outputs.github_oidc_provider_arn
  subjects          = var.github_frontend_oidc_subjects
  policy_json       = data.aws_iam_policy_document.github_frontend_deploy[0].json
}
