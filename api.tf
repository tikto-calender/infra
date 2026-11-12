locals {
  api_edges = {
    for environment, edge in {
      dev = {
        enabled           = var.enable_dev_edge
        security_group_id = aws_security_group.dev_cloudfront_origin.id
        listener_port     = 80
      }
      prod = {
        enabled           = var.enable_edge
        security_group_id = aws_security_group.cloudfront_origin.id
        listener_port     = var.internal_alb_listener_port
      }
    } : environment => edge if edge.enabled
  }
}

resource "aws_lb" "api" {
  for_each = local.api_edges

  name               = "${var.project_name}-${each.key}-eks-edge"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [each.value.security_group_id]
  subnets            = module.network.public_subnet_ids
}

resource "aws_lb_target_group" "backend" {
  for_each = local.api_edges

  name        = "${var.project_name}-${each.key}-eks-backend"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.network.vpc_id

  health_check {
    path    = "/api/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "api" {
  for_each = local.api_edges

  load_balancer_arn = aws_lb.api[each.key].arn
  port              = each.value.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[each.key].arn
  }
}

resource "aws_lb_target_group" "frontend" {
  for_each = local.api_edges

  name        = "${var.project_name}-${each.key}-eks-frontend"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.network.vpc_id

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_alb" {
  for_each = local.api_edges

  security_group_id = each.value.security_group_id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value.listener_port
  to_port           = each.value.listener_port
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_frontend_alb" {
  for_each = local.api_edges

  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = each.value.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_lb_listener_rule" "backend" {
  for_each = { for key, value in local.api_edges : key => value if key != "prod" }

  listener_arn = aws_lb_listener.api[each.key].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }
}

resource "aws_lb_listener_rule" "prod_backend" {
  for_each = { for key, value in local.api_edges : key => value if key == "prod" }

  listener_arn = aws_lb_listener.api[each.key].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[each.key].arn
  }

  lifecycle {
    ignore_changes = [action]
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_api" {
  for_each = local.api_edges

  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = each.value.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

output "backend_target_group_names" {
  value = { for environment, target_group in aws_lb_target_group.backend : environment => target_group.name }
}

output "frontend_target_group_names" {
  value = { for environment, target_group in aws_lb_target_group.frontend : environment => target_group.name }
}

moved {
  from = aws_lb_listener_rule.backend["prod"]
  to   = aws_lb_listener_rule.prod_backend["prod"]
}

resource "aws_lb_target_group" "backend_green" {
  count = var.enable_edge ? 1 : 0

  name        = "${var.project_name}-prod-eks-backend-green"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.network.vpc_id

  health_check {
    path    = "/api/health"
    matcher = "200"
  }
}

locals {
  prod_backend_slots = var.enable_edge ? {
    blue  = aws_lb_target_group.backend["prod"].arn
    green = aws_lb_target_group.backend_green[0].arn
  } : {}
}

resource "aws_lb_listener_rule" "backend_preview" {
  for_each = length(var.preview_runner_cidrs) == 0 ? {} : local.prod_backend_slots

  listener_arn = aws_lb_listener.api["prod"].arn
  priority     = each.key == "blue" ? 10 : 11

  action {
    type             = "forward"
    target_group_arn = each.value
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }

  condition {
    http_header {
      http_header_name = "X-TikTo-Preview"
      values           = [each.key]
    }
  }

  condition {
    source_ip {
      values = var.preview_runner_cidrs
    }
  }
}

output "backend_release_rule_arn" {
  value = try(aws_lb_listener_rule.prod_backend["prod"].arn, null)
}

output "backend_release_target_arns" {
  value = local.prod_backend_slots
}
