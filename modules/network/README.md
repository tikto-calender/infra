# Network

Creates a VPC, public subnets, an Internet Gateway, a public route table, and a default security group. Kubernetes subnet discovery tags are optional.

The shared EKS root uses these subnets for worker nodes, cluster network interfaces, and both ALBs. Nodes reach external services through the Internet Gateway.

See [resources and routes](main.tf), [inputs](variables.tf), and [VPC and subnet outputs](outputs.tf).
