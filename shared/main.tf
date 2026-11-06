module "ecr" {
  source = "../modules/ecr"

  repository_names = toset([
    "${var.project_name}/backend",
    "${var.project_name}/notification"
  ])
  keep_image_count = var.keep_image_count
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-actions"
  }
}

data "aws_iam_policy_document" "github_build" {
  statement {
    sid       = "GetEcrToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = values(module.ecr.repository_arns)
  }
}

module "github_build_role" {
  source = "../modules/github-oidc-role"

  name              = "${var.project_name}-github-build"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  subjects          = var.github_build_oidc_subjects
  policy_json       = data.aws_iam_policy_document.github_build.json
}

data "aws_iam_policy_document" "github_terraform_plan" {
  statement {
    sid       = "ListTerraformState"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.project_name}/*"]
    }
  }

  statement {
    sid = "ReadTerraformState"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/${var.project_name}/*"]
  }

  statement {
    sid = "LockTerraformState"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/${var.project_name}/*.tflock"]
  }
}

module "github_terraform_plan_role" {
  source = "../modules/github-oidc-role"

  name              = "${var.project_name}-github-terraform-plan"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  subjects          = var.github_plan_oidc_subjects
  policy_json       = data.aws_iam_policy_document.github_terraform_plan.json
}

resource "aws_iam_role_policy_attachment" "github_terraform_plan_view_only" {
  role       = module.github_terraform_plan_role.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}
