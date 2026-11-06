variable "cluster_name" {
  type        = string
  description = "EKS cluster name monitored by CloudWatch."
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Retention for Container Insights log groups."
}

variable "alarm_actions" {
  type        = list(string)
  default     = []
  description = "SNS topic ARNs invoked when an alarm changes state."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags."
}
