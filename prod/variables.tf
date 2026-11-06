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

variable "map_public_ip_on_launch" {
  type        = bool
  description = "Assign public IPv4 addresses to EC2 instances launched in public subnets."
}

variable "log_retention_days" {
  type        = number
  description = "Retention for EKS and application logs, in days."
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

variable "kubernetes_version" {
  type        = string
  default     = "1.36"
  description = "EKS version in standard support."
}

variable "cluster_public_access_cidrs" {
  type        = list(string)
  description = "Trusted operator CIDRs, normally a VPN range or public IP with /32."

  validation {
    condition = alltrue([
      for cidr in var.cluster_public_access_cidrs :
      !contains(["0.0.0.0/0", "::/0"], trimspace(cidr))
    ])
    error_message = "Do not expose the EKS API to 0.0.0.0/0 or ::/0."
  }
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
  description = "Enable only after GitOps has created the named internet-facing ALB."
}

variable "internal_alb_name" {
  type        = string
  default     = "tikto-prod-api"
  description = "Stable public ALB name configured by the production Kubernetes Ingress. The variable retains its legacy name."
}

variable "internal_alb_listener_port" {
  type        = number
  default     = 80
  description = "Public ALB origin listener port. The variable retains its legacy name."
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

variable "github_frontend_oidc_subjects" {
  type        = list(string)
  description = "Exact GitHub OIDC subjects allowed to deploy the production frontend."
}

variable "web_acl_id" {
  type        = string
  default     = null
  description = "Optional CloudFront WAFv2 web ACL ARN."
}
