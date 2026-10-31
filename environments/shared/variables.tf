variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "tikto"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
}

variable "nat_gateway_mode" {
  type        = string
  default     = "single"
  description = "Use single for lower cost or one_per_az for zonal availability."
}

variable "keep_image_count" {
  type    = number
  default = 30
}

variable "terraform_state_bucket_name" {
  type        = string
  description = "Existing S3 bucket created by bootstrap and used by the GitHub Terraform plan role."
}

variable "github_build_oidc_subjects" {
  type        = list(string)
  description = "Exact GitHub OIDC subjects allowed to build and push images."
}

variable "github_plan_oidc_subjects" {
  type        = list(string)
  description = "Exact GitHub OIDC subjects allowed to run the read-only Terraform plan workflow."
}
