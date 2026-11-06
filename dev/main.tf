locals {
  name = "${var.project_name}-dev"
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

  name                 = local.name
  vpc_cidr             = var.network.vpc_cidr
  availability_zones   = var.network.availability_zones
  public_subnet_cidrs  = var.network.public_subnet_cidrs
  private_subnet_cidrs = var.network.private_subnet_cidrs
  nat_gateway_mode     = var.network.nat_gateway_mode
}

module "database" {
  source = "../modules/dynamodb"

  name                   = "${local.name}-app"
  point_in_time_recovery = false
  deletion_protection    = false
}

module "application" {
  source = "../modules/ecs-application"

  name                       = local.name
  environment                = "dev"
  aws_region                 = var.aws_region
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.public_subnet_ids
  assign_public_ip           = var.assign_public_ip
  backend_image              = var.backend_image
  notification_image         = var.notification_image
  dynamodb_table_name        = module.database.name
  dynamodb_table_arn         = module.database.arn
  backend_desired_count      = var.backend_desired_count
  notification_desired_count = var.notification_desired_count
  capacity_provider          = var.capacity_provider
  container_insights         = false
  log_retention_days         = var.log_retention_days
}

module "edge" {
  source = "../modules/cloudfront"

  name                 = local.name
  bucket_name          = var.frontend_bucket_name
  force_destroy_bucket = true
  aliases              = var.frontend_aliases
  acm_certificate_arn  = var.frontend_acm_certificate_arn
  route53_zone_id      = var.frontend_route53_zone_id

  api_origin = {
    domain_name            = module.application.alb_dns_name
    type                   = "custom"
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
  }
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid = "UpdateEcsServices"
    actions = [
      "ecs:DescribeServices",
      "ecs:ListServiceDeployments",
      "ecs:UpdateService"
    ]
    resources = [
      module.application.backend_service_arn,
      module.application.notification_service_arn
    ]
  }

  statement {
    sid = "RegisterTaskDefinitions"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "PassEcsRoles"
    actions = ["iam:PassRole"]
    resources = [
      module.application.task_execution_role_arn,
      module.application.backend_task_role_arn,
      module.application.notification_task_role_arn
    ]
  }

  statement {
    sid = "DeployFrontend"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${module.edge.bucket_name}",
      "arn:aws:s3:::${module.edge.bucket_name}/*"
    ]
  }

  statement {
    sid       = "InvalidateFrontend"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [module.edge.distribution_arn]
  }
}

module "github_deploy_role" {
  source = "../modules/github-oidc-role"

  name              = "${local.name}-github-deploy"
  oidc_provider_arn = data.terraform_remote_state.shared.outputs.github_oidc_provider_arn
  subjects          = var.github_oidc_subjects
  policy_json       = data.aws_iam_policy_document.github_deploy.json
}
