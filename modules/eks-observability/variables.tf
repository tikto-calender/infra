variable "cluster_name" {
  type        = string
  description = "EKS cluster name monitored by CloudWatch."
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Retention for Container Insights log groups."
}

variable "namespace" {
  type        = string
  default     = "observability"
  description = "Kubernetes namespace for observability service accounts."
}

variable "adot_service_account" {
  type        = string
  default     = "otel-collector"
  description = "Service account used by the ADOT collector."
}

variable "fluent_bit_service_account" {
  type        = string
  default     = "fluent-bit"
  description = "Service account used by Fluent Bit."
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
