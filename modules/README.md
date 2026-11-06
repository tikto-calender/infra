# Terraform Modules

Each module defines a reusable unit of infrastructure. The root stacks in [Shared](../shared/main.tf), [Dev](../dev/main.tf), and [Prod](../prod/main.tf) select the modules and supply environment-specific settings. Run Terraform from a root stack.

| Module | Responsibility | Root stacks |
| --- | --- | --- |
| [Network](network/README.md) | VPCs, subnets, routing, and optional NAT | Dev, Prod |
| [DynamoDB](dynamodb/README.md) | Tables for the TikTo task and event schema | Dev, Prod |
| [ECR](ecr/README.md) | Container image repositories and lifecycle policies | Shared |
| [ECS Application](ecs-application/README.md) | TikTo Backend and Notification services on ECS Fargate | Dev |
| [EKS Platform](eks-platform/README.md) | EKS cluster, managed nodes, add-ons, and Pod Identity | Prod |
| [EKS Observability](eks-observability/README.md) | CloudWatch logs, metrics, dashboard, and alarms | Prod |
| [CloudFront](cloudfront/README.md) | Private S3 hosting and CloudFront API routing | Dev, Prod |
| [GitHub OIDC Role](github-oidc-role/README.md) | AWS IAM roles for GitHub Actions | Shared, Dev, Prod |

## Module boundaries

- Root stacks choose values such as VPC CIDRs, subnet placement, image URIs, replica counts, and IAM policy scope.
- Within a module, `variables.tf` defines the inputs, `main.tf` defines the resources, and `outputs.tf` exposes values that callers can use.
- Network and GitHub OIDC Role are shared infrastructure building blocks. ECS Application and DynamoDB are TikTo-specific modules with fixed service or schema contracts. Their individual READMEs identify which settings callers can change.
