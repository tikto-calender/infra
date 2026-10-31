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

variable "kubernetes_version" {
  type        = string
  default     = "1.36"
  description = "EKS version in standard support."
}

variable "cluster_public_access_cidrs" {
  type        = list(string)
  description = "Trusted operator CIDRs, normally a VPN range or public IP with /32."
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3a.medium", "t3.medium"]
}

variable "node_capacity_type" {
  type    = string
  default = "SPOT"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "monitoring_alarm_actions" {
  type        = list(string)
  default     = []
  description = "Optional SNS topic ARNs for CloudWatch alarms."
}

variable "enable_edge" {
  type        = bool
  default     = false
  description = "Enable only after GitOps has created the named internal ALB."
}

variable "internal_alb_name" {
  type        = string
  default     = "tikto-prod-api"
  description = "Stable ALB name configured by the production Kubernetes Ingress."
}

variable "internal_alb_listener_port" {
  type    = number
  default = 80
}

variable "frontend_bucket_name" {
  type        = string
  default     = null
  description = "Globally unique production frontend bucket; required when enable_edge is true."
}

variable "frontend_aliases" {
  type    = list(string)
  default = []
}

variable "frontend_acm_certificate_arn" {
  type        = string
  default     = null
  description = "ACM certificate in us-east-1, required when aliases are configured."
}

variable "frontend_route53_zone_id" {
  type        = string
  default     = null
  description = "Optional Route 53 hosted zone ID for frontend aliases."
}

variable "web_acl_id" {
  type        = string
  default     = null
  description = "Optional CloudFront WAFv2 web ACL ARN."
}
