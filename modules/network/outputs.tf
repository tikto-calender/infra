output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "VPC CIDR."
}

output "internet_gateway_id" {
  value       = aws_internet_gateway.this.id
  description = "Internet gateway ID. CloudFront VPC origins require the VPC to have an IGW attached."
}

output "public_subnet_ids" {
  value       = [for az in var.availability_zones : aws_subnet.public[az].id]
  description = "Public subnet IDs ordered like availability_zones."
}

output "private_subnet_ids" {
  value       = [for az in var.availability_zones : aws_subnet.private[az].id]
  description = "Private subnet IDs ordered like availability_zones."
}

output "nat_gateway_ids" {
  value       = aws_nat_gateway.this[*].id
  description = "NAT gateway IDs, empty when NAT is disabled."
}
