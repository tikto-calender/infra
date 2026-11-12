variable "network" {
  description = "VPC address ranges, availability zones, and NAT topology for this environment."
  type = object({
    vpc_cidr            = string
    availability_zones  = list(string)
    public_subnet_cidrs = list(string)
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

variable "kubernetes_version" {
  type        = string
  default     = "1.36"
  description = "EKS version in standard support."
}

variable "eks_admin_role_arns" {
  type        = set(string)
  default     = []
  description = "Additional IAM role ARNs that receive cluster-wide Kubernetes administrator access."
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "node_min_size" {
  type    = number
  default = 3
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "legacy_node_group" {
  description = "Live settings for the old system node group while draining it. Leave null for new clusters."
  type = object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    desired_size   = number
    max_size       = number
  })
  default = null
}

variable "enable_dev_edge" {
  type        = bool
  default     = true
  description = "Provision the development ALB and frontend edge resources."
}

variable "monitoring_alarm_actions" {
  type        = list(string)
  default     = []
  description = "Optional SNS topic ARNs for CloudWatch alarms."
}

variable "enable_edge" {
  type        = bool
  default     = true
  description = "Provision the production ALB and frontend edge resources."
}

variable "internal_alb_listener_port" {
  type        = number
  default     = 80
  description = "Public ALB origin listener port. The variable retains its legacy name."
}

variable "preview_runner_cidrs" {
  type        = list(string)
  default     = []
  description = "Fixed egress CIDRs of the production smoke-test runner. An empty list disables preview routing."

  validation {
    condition     = length(var.preview_runner_cidrs) <= 2 && alltrue([for cidr in var.preview_runner_cidrs : can(cidrhost(cidr, 0)) && tonumber(split("/", cidr)[1]) > 0])
    error_message = "Specify up to two restricted runner CIDRs."
  }
}

variable "github_oidc_provider_arn" {
  type        = string
  default     = null
  description = "Existing AWS IAM GitHub Actions OIDC provider ARN for the manifest production job."
}
