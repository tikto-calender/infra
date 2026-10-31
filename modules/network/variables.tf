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
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per availability zone."
  type        = list(string)
}

variable "nat_gateway_mode" {
  description = "NAT topology: none, single, or one_per_az."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "single", "one_per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be none, single, or one_per_az."
  }
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
