# ECS Application

Deploys the TikTo Backend and Notification services on ECS Fargate. It creates the cluster, task definitions, services, Public ALB, Service Connect namespace, IAM roles, and CloudWatch log groups.

The caller supplies the network, image URIs, DynamoDB table, and runtime settings such as CPU, memory, and task counts. The two services, their ports (`3000` and `8000`), and their health check paths are part of the TikTo application contract. Dev currently uses this module.

See [ECS services, ALB, and IAM](main.tf), [runtime inputs](variables.tf), and [service outputs](outputs.tf).
