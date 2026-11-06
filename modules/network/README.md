# Network

Creates a VPC with public and private subnets, route tables, an Internet Gateway, and a default security group. NAT gateways and Kubernetes subnet discovery tags are optional.

Dev and Prod each call this module with their own VPC CIDR, availability zones, subnet CIDRs, and public IP settings. Both currently disable NAT. Public subnets host the ALBs and workload compute, while Prod also uses private subnets for EKS control-plane network interfaces.

See [resources and routes](main.tf), [inputs](variables.tf), and [VPC and subnet outputs](outputs.tf).
