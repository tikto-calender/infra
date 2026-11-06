variable "network" {
  description = "VPC address ranges, availability zones, and NAT topology for this environment."
  type = object({
    vpc_cidr             = string
    availability_zones   = list(string)
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
    nat_gateway_mode     = string
  })
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IPv4 address to each ECS task."
}

variable "log_retention_days" {
  type        = number
  description = "Retention for ECS application logs, in days."
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project_name" {
  type    = string
  default = "tikto"
}

variable "terraform_state_bucket_name" {
  type        = string
  default     = "tikto-terraform-state"
  description = "S3 bucket that stores the shared Terraform state."
}

variable "terraform_state_region" {
  type        = string
  default     = "ap-southeast-2"
  description = "AWS region containing the Terraform state bucket."
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
