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
  name               = "${var.cluster_name}-cloudwatch-agent"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.adot.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = var.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  pod_identity_association {
    service_account = "cloudwatch-agent"
    role_arn        = aws_iam_role.adot.arn
  }

  depends_on = [aws_iam_role_policy_attachment.cloudwatch_agent]

  tags = local.common_tags
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
