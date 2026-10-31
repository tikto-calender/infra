variable "name" {
  type        = string
  description = "DynamoDB table name."
}

variable "point_in_time_recovery" {
  type        = bool
  description = "Enable point-in-time recovery."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Protect the table from accidental deletion."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
