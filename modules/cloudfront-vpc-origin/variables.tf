variable "name" {
  type        = string
  description = "CloudFront VPC origin name."
}

variable "origin_arn" {
  type        = string
  description = "ARN of the internal ALB, NLB, or EC2 origin."
}

variable "http_port" {
  type        = number
  default     = 80
  description = "Origin HTTP port."
}

variable "https_port" {
  type        = number
  default     = 443
  description = "Origin HTTPS port."
}

variable "origin_protocol_policy" {
  type        = string
  default     = "http-only"
  description = "Protocol used between CloudFront and the VPC origin."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags."
}
