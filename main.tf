locals {
  name = "${var.project_name}-prod"
}

module "network" {
  source = "./modules/network"

  name                    = local.name
  vpc_cidr                = var.network.vpc_cidr
  availability_zones      = var.network.availability_zones
  public_subnet_cidrs     = var.network.public_subnet_cidrs
  map_public_ip_on_launch = var.map_public_ip_on_launch
  kubernetes_cluster_name = "${local.name}-eks"
}

module "database" {
  source = "./modules/dynamodb"

  name                   = "${local.name}-app"
  point_in_time_recovery = true
  deletion_protection    = true
}

module "eks" {
  source = "./modules/eks-platform"

  name                        = "${local.name}-eks"
  kubernetes_version          = var.kubernetes_version
  subnet_ids                  = module.network.public_subnet_ids
  node_instance_types         = var.node_instance_types
  node_capacity_type          = var.node_capacity_type
  node_min_size               = var.node_min_size
  node_desired_size           = var.node_desired_size
  node_max_size               = var.node_max_size
  legacy_node_group           = var.legacy_node_group
  dynamodb_table_arn          = module.database.arn
  dev_application             = { dynamodb_table_arn = module.dev_database.arn }
  application_namespace       = "tikto-prod"
  application_service_account = "tikto-app"
  log_retention_days          = var.log_retention_days
  enable_secrets_encryption   = true
}

resource "aws_eks_access_entry" "admin" {
  for_each = var.eks_admin_role_arns

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = aws_eks_access_entry.admin

  cluster_name  = each.value.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

module "observability" {
  source = "./modules/eks-observability"

  cluster_name       = module.eks.cluster_name
  log_retention_days = var.log_retention_days
  alarm_actions      = var.monitoring_alarm_actions

  depends_on = [module.eks]
}

# Keep the existing name and description for compatibility with earlier ALB state.
resource "aws_security_group" "cloudfront_origin" {
  name        = "${local.name}-cloudfront-origin"
  description = "CloudFront access to the production internal ALB"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${local.name}-cloudfront-origin"
  }
}

resource "aws_vpc_security_group_egress_rule" "cloudfront_origin_to_vpc" {
  security_group_id = aws_security_group.cloudfront_origin.id
  description       = "ALB traffic to targets inside the production VPC"
  cidr_ipv4         = module.network.vpc_cidr
  ip_protocol       = "-1"
}
