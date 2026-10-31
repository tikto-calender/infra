variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "tikto"
}

variable "terraform_state_bucket_name" {
  type        = string
  description = "S3 bucket that stores the shared Terraform state."
}

variable "shared_state_key" {
  type        = string
  default     = "tikto/shared/terraform.tfstate"
  description = "S3 key of the shared stack state."
}

variable "backend_image" {
  type        = string
  description = "Immutable ECR image URI for the backend."
}

variable "notification_image" {
  type        = string
  description = "Immutable ECR image URI for notification service."
}

variable "backend_image_tag" {
  type        = string
  description = "Git SHA or version displayed by /api/runtime."
}

variable "app_version" {
  type    = string
  default = "dev"
}

variable "frontend_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for the dev frontend."
}

variable "frontend_aliases" {
  type    = list(string)
  default = []
}

variable "frontend_acm_certificate_arn" {
  type        = string
  default     = null
  description = "ACM certificate in us-east-1, required when frontend_aliases is non-empty."
}

variable "frontend_route53_zone_id" {
  type        = string
  default     = null
  description = "Optional Route 53 hosted zone ID for frontend aliases."
}

variable "backend_desired_count" {
  type    = number
  default = 1
}

variable "notification_desired_count" {
  type    = number
  default = 1
}

variable "capacity_provider" {
  type    = string
  default = "FARGATE"
}

variable "github_oidc_subjects" {
  type        = list(string)
  description = "Exact GitHub OIDC subjects allowed to deploy dev."
}
