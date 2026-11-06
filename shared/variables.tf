variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type    = string
  default = "tikto"
}

variable "keep_image_count" {
  type    = number
  default = 30
}

variable "terraform_state_bucket_name" {
  type        = string
  default     = "tikto-terraform-state"
  description = "Existing S3 bucket used by Terraform and the GitHub Terraform plan role."
}

variable "github_build_oidc_subjects" {
  type        = list(string)
  description = "Exact GitHub OIDC subjects allowed to build and push images."
}

variable "github_plan_oidc_subjects" {
  type        = list(string)
  description = "Exact GitHub OIDC subjects allowed to run the read-only Terraform plan workflow."
}
