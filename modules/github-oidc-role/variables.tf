variable "name" {
  type        = string
  description = "IAM role name."
}

variable "oidc_provider_arn" {
  type        = string
  description = "GitHub Actions IAM OIDC provider ARN."
}

variable "subjects" {
  type        = list(string)
  description = "Allowed token.actions.githubusercontent.com subject claims."

  validation {
    condition     = length(var.subjects) > 0
    error_message = "At least one exact GitHub OIDC subject is required."
  }
}

variable "policy_json" {
  type        = string
  description = "Least-privilege permissions granted to the workflow."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags."
}
