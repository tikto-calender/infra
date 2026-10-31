variable "repository_names" {
  type        = set(string)
  description = "ECR repository names."
}

variable "keep_image_count" {
  type        = number
  description = "Number of tagged images retained per repository."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
