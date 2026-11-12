# Terraform Modules

Each module defines a reusable unit of infrastructure. Run Terraform from the [Infrastructure root](../main.tf), which configures both environments.

| Module | Responsibility | Use |
| --- | --- | --- |
| [Network](network/README.md) | VPC, public subnets, and Internet Gateway routing | Active |
| [DynamoDB](dynamodb/README.md) | Tables for the TikTo task and event schema | Active |
| [EKS Platform](eks-platform/README.md) | EKS cluster, managed nodes, add-ons, and Pod Identity | Active |
| [EKS Observability](eks-observability/README.md) | CloudWatch logs, metrics, dashboard, and alarms | Active |

## Module boundaries

- Root stacks choose values such as VPC CIDRs, subnet placement, image URIs, replica counts, and IAM policy scope.
- Within a module, `variables.tf` defines the inputs, `main.tf` defines the resources, and `outputs.tf` exposes values that callers can use.
- The module READMEs identify which settings callers can change.
