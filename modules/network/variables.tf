variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by this environment."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Use at least two availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per availability zone."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Provide one public subnet CIDR for each availability zone."
  }
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign public IPv4 addresses to instances launched in public subnets."
  type        = bool
  default     = false
}

variable "kubernetes_cluster_name" {
  description = "Optional EKS cluster name used to tag subnets for load balancer discovery."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for all resources."
  type        = map(string)
  default     = {}
}
