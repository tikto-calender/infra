data "aws_iam_policy_document" "backend_release_trust" {
  count = var.enable_edge && var.github_oidc_provider_arn != null ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:tikto-calender/manifest:environment:prod"]
    }
  }
}

resource "aws_iam_role" "backend_release" {
  count = length(data.aws_iam_policy_document.backend_release_trust)

  name               = "${var.project_name}-prod-backend-release"
  assume_role_policy = data.aws_iam_policy_document.backend_release_trust[0].json
}

resource "aws_iam_role_policy" "backend_release" {
  count = length(aws_iam_role.backend_release)

  name = "backend-release"
  role = aws_iam_role.backend_release[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:ModifyRule"]
        Resource = aws_lb_listener_rule.prod_backend["prod"].arn
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:DescribeRules", "elasticloadbalancing:DescribeTargetHealth", "cloudwatch:GetMetricStatistics"]
        Resource = "*"
      }
    ]
  })
}

output "backend_release_role_arn" {
  value = try(aws_iam_role.backend_release[0].arn, null)
}
