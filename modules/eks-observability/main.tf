locals {
  common_tags = merge(var.tags, {
    ManagedBy = "Terraform"
    Module    = "eks-observability"
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "performance" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "adot" {
  name               = "${var.cluster_name}-adot"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "adot" {
  statement {
    sid       = "PublishContainerInsightsMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["ContainerInsights"]
    }
  }

  statement {
    sid = "WritePerformanceLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.performance.arn}:*"]
  }
}

resource "aws_iam_role_policy" "adot" {
  name   = "container-insights"
  role   = aws_iam_role.adot.id
  policy = data.aws_iam_policy_document.adot.json
}

resource "aws_eks_pod_identity_association" "adot" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.adot_service_account
  role_arn        = aws_iam_role.adot.arn
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${var.cluster_name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "fluent_bit" {
  statement {
    sid = "WriteApplicationLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.application.arn}:*"]
  }
}

resource "aws_iam_role_policy" "fluent_bit" {
  name   = "application-logs"
  role   = aws_iam_role.fluent_bit.id
  policy = data.aws_iam_policy_document.fluent_bit.json
}

resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.fluent_bit_service_account
  role_arn        = aws_iam_role.fluent_bit.arn
}

resource "aws_cloudwatch_dashboard" "eks" {
  dashboard_name = "${var.cluster_name}-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Node utilization"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name],
            [".", "node_memory_utilization", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Pods and restarts"
          view   = "timeSeries"
          region = data.aws_region.current.region
          metrics = [
            ["ContainerInsights", "cluster_number_of_running_pods", "ClusterName", var.cluster_name],
            [".", "pod_number_of_container_restarts", ".", "."]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Recent application errors"
          region = data.aws_region.current.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.application.name}' | fields @timestamp, kubernetes.namespace_name, kubernetes.pod_name, @message | filter @message like /(?i)(error|exception|fatal)/ | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}

data "aws_region" "current" {}

resource "aws_cloudwatch_metric_alarm" "node_cpu" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  alarm_description   = "Average EKS node CPU utilization is above 85 percent."
  namespace           = "ContainerInsights"
  metric_name         = "node_cpu_utilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  actions_enabled     = length(var.alarm_actions) > 0

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "node_memory" {
  alarm_name          = "${var.cluster_name}-node-memory-high"
  alarm_description   = "Average EKS node memory utilization is above 85 percent."
  namespace           = "ContainerInsights"
  metric_name         = "node_memory_utilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  actions_enabled     = length(var.alarm_actions) > 0

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "failed_nodes" {
  alarm_name          = "${var.cluster_name}-failed-nodes"
  alarm_description   = "One or more EKS nodes are in a failed condition."
  namespace           = "ContainerInsights"
  metric_name         = "cluster_failed_node_count"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  actions_enabled     = length(var.alarm_actions) > 0

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = local.common_tags
}
