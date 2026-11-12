variable "name" {
  type        = string
  description = "EKS cluster name."
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes minor version. Use a version in standard support."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the control plane network interfaces and managed node group."
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3a.medium", "t3.medium"]
  description = "Instance types used by the managed node group."
}

variable "node_capacity_type" {
  type        = string
  default     = "SPOT"
  description = "SPOT or ON_DEMAND."

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.node_capacity_type)
    error_message = "node_capacity_type must be SPOT or ON_DEMAND."
  }
}

variable "node_min_size" {
  type        = number
  default     = 2
  description = "Minimum managed nodes."
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired managed nodes."
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Maximum managed nodes."
}

variable "node_disk_size" {
  type        = number
  default     = 30
  description = "Encrypted gp3 node disk size in GiB."
}

variable "legacy_node_group" {
  description = "Existing system node group settings during migration. Null removes the group."
  type = object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    desired_size   = number
    max_size       = number
  })
  default = null
}

variable "control_plane_log_types" {
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  description = "EKS control plane log types sent to CloudWatch."
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "CloudWatch log retention."
}

variable "enable_secrets_encryption" {
  type        = bool
  default     = true
  description = "Encrypt Kubernetes secrets with a customer-managed KMS key."
}

variable "dynamodb_table_arn" {
  type        = string
  description = "Application DynamoDB table ARN."
}

variable "dev_application" {
  type        = object({ dynamodb_table_arn = string })
  default     = null
  description = "Optional dev DynamoDB table for a separate Pod Identity role."
}

variable "application_namespace" {
  type        = string
  default     = "tikto-prod"
  description = "Kubernetes namespace that contains the backend service account."
}

variable "application_service_account" {
  type        = string
  default     = "tikto-app"
  description = "Backend Kubernetes service account."
}

variable "alb_controller_service_account" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "AWS Load Balancer Controller service account."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags."
}
