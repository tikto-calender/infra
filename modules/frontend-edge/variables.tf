variable "name" {
  description = "Name prefix for edge resources."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for the frontend artifact."
  type        = string
}

variable "api_origin" {
  description = "Optional API origin. Use type custom for a public ALB or vpc for a CloudFront VPC origin."
  type = object({
    domain_name            = string
    type                   = string
    vpc_origin_id          = optional(string)
    http_port              = optional(number, 80)
    https_port             = optional(number, 443)
    origin_protocol_policy = optional(string, "http-only")
  })
  default = null

  validation {
    condition = var.api_origin == null || contains(
      ["custom", "vpc"],
      try(var.api_origin.type, "")
    )
    error_message = "api_origin.type must be custom or vpc."
  }
}

variable "aliases" {
  description = "CloudFront aliases. Leave empty to use the cloudfront.net hostname."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 when aliases are configured."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Optional Route 53 hosted zone ID used to create alias records."
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_200 includes Asia edge locations."
  type        = string
  default     = "PriceClass_200"
}

variable "force_destroy_bucket" {
  description = "Allow Terraform to remove a non-empty frontend bucket. Keep false in production."
  type        = bool
  default     = false
}

variable "web_acl_id" {
  description = "Optional WAFv2 web ACL ARN."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
