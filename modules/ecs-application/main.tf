locals {
  backend_port      = 3000
  notification_port = 8000

  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "ecs-application"
  })

  backend_environment = merge({
    APP_ENV                         = var.environment
    PORT                            = tostring(local.backend_port)
    STORE_BACKEND                   = "dynamodb"
    DYNAMODB_TABLE                  = var.dynamodb_table_name
    AWS_REGION                      = var.aws_region
    NOTIFICATION_SERVICE_URL        = "http://notification:${local.notification_port}"
    NOTIFICATION_SERVICE_TIMEOUT_MS = "2500"
  }, var.backend_environment)

  notification_environment = merge({
    PORT = tostring(local.notification_port)
  }, var.notification_environment)
}

data "aws_caller_identity" "current" {}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "backend" {
  name               = "${var.name}-backend-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "backend" {
  statement {
    sid = "UseApplicationTable"
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem"
    ]
    resources = [
      var.dynamodb_table_arn,
      "${var.dynamodb_table_arn}/index/*"
    ]
  }
}

resource "aws_iam_role_policy" "backend" {
  name   = "dynamodb"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.backend.json
}

resource "aws_iam_role" "notification" {
  name               = "${var.name}-notification-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    sid = "EcsExecChannels"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "backend_exec" {
  name   = "ecs-exec"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}

resource "aws_iam_role_policy" "notification_exec" {
  name   = "ecs-exec"
  role   = aws_iam_role.notification.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.name}/backend"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "notification" {
  name              = "/ecs/${var.name}/notification"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.this.arn
  }

  tags = local.common_tags
}

resource "aws_service_discovery_http_namespace" "this" {
  name        = "${var.name}.internal"
  description = "ECS Service Connect namespace for ${var.name}"
  tags        = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Accept API traffic only from CloudFront"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the CloudFront origin-facing managed prefix list"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "Fargate application tasks"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-tasks" })
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Backend traffic from the ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = local.backend_port
  to_port                      = local.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "service_connect" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Service Connect traffic between application tasks"
  referenced_security_group_id = aws_security_group.tasks.id
  from_port                    = local.notification_port
  to_port                      = local.notification_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to backend tasks"
  referenced_security_group_id = aws_security_group.tasks.id
  from_port                    = local.backend_port
  to_port                      = local.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "tasks" {
  security_group_id = aws_security_group.tasks.id
  description       = "Application egress for AWS APIs, ECR, and notification providers"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb" "api" {
  name                       = substr("${var.name}-api", 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-api"
  })
}

resource "aws_lb_target_group" "backend" {
  name        = substr("${var.name}-backend", 0, 32)
  port        = local.backend_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "notification" {
  family                   = "${var.name}-notification"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.notification_cpu)
  memory                   = tostring(var.notification_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.notification.arn

  container_definitions = jsonencode([
    {
      name      = "notification"
      image     = var.notification_image
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          name          = "notification"
          containerPort = local.notification_port
          hostPort      = local.notification_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        for key, value in local.notification_environment : {
          name  = key
          value = value
        }
      ]
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${local.notification_port}/health', timeout=3)\" || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.notification.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.notification_exec
  ]

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.backend_cpu)
  memory                   = tostring(var.backend_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.backend.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          name          = "backend"
          containerPort = local.backend_port
          hostPort      = local.backend_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        for key, value in local.backend_environment : {
          name  = key
          value = value
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:${local.backend_port}/api/health >/dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.backend,
    aws_iam_role_policy.backend_exec
  ]

  tags = local.common_tags
}

resource "aws_ecs_service" "notification" {
  name            = "notification"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.notification.arn
  desired_count   = var.notification_desired_count

  enable_execute_command             = true
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 1
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = var.assign_public_ip
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.this.arn

    service {
      port_name      = "notification"
      discovery_name = "notification"

      client_alias {
        dns_name = "notification"
        port     = local.notification_port
      }
    }
  }

  propagate_tags = "SERVICE"
  tags           = local.common_tags

  # CI/CD owns the deployed revision after Terraform bootstraps the service.
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]
}

resource "aws_ecs_service" "backend" {
  name            = "backend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count

  enable_execute_command             = true
  health_check_grace_period_seconds  = 30
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 1
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = local.backend_port
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.this.arn
  }

  propagate_tags = "SERVICE"
  tags           = local.common_tags

  depends_on = [
    aws_ecs_cluster_capacity_providers.this,
    aws_ecs_service.notification,
    aws_lb_listener.http
  ]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
