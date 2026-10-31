variable "name" {
  type        = string
  description = "Name prefix for ECS resources."
}

variable "environment" {
  type        = string
  description = "Application environment name."
}

variable "aws_region" {
  type        = string
  description = "AWS region passed to the application."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets used by the internet-facing ALB and Fargate tasks."
}

variable "backend_image" {
  type        = string
  description = "Immutable backend image URI including its tag or digest."
}

variable "notification_image" {
  type        = string
  description = "Immutable notification image URI including its tag or digest."
}

variable "backend_image_tag" {
  type        = string
  description = "Image tag or Git SHA exposed by /api/runtime."
}

variable "app_version" {
  type        = string
  description = "Application version exposed by /api/runtime."
  default     = "dev"
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB table used by the backend."
}

variable "dynamodb_table_arn" {
  type        = string
  description = "DynamoDB table ARN used for the backend task role."
}

variable "backend_cpu" {
  type        = number
  default     = 256
  description = "Backend task CPU units."
}

variable "backend_memory" {
  type        = number
  default     = 512
  description = "Backend task memory in MiB."
}

variable "notification_cpu" {
  type        = number
  default     = 256
  description = "Notification task CPU units."
}

variable "notification_memory" {
  type        = number
  default     = 512
  description = "Notification task memory in MiB."
}

variable "backend_desired_count" {
  type        = number
  default     = 1
  description = "Desired backend task count."
}

variable "notification_desired_count" {
  type        = number
  default     = 1
  description = "Desired notification task count. Keep at one while it stores state in memory."
}

variable "capacity_provider" {
  type        = string
  default     = "FARGATE"
  description = "FARGATE or FARGATE_SPOT."

  validation {
    condition     = contains(["FARGATE", "FARGATE_SPOT"], var.capacity_provider)
    error_message = "capacity_provider must be FARGATE or FARGATE_SPOT."
  }
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Give tasks public egress. Useful in a low-cost dev VPC without NAT."
}

variable "container_insights" {
  type        = bool
  default     = false
  description = "Enable ECS Container Insights."
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "CloudWatch log retention."
}

variable "backend_environment" {
  type        = map(string)
  default     = {}
  description = "Additional non-secret backend environment variables."
}

variable "notification_environment" {
  type        = map(string)
  default     = {}
  description = "Additional non-secret notification environment variables."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags."
}
