# Terraform environments

Only folders in this directory are executable Terraform root modules. Reusable modules live in `../modules` and must not be applied directly.

## State and dependency graph

```text
bootstrap (local state)
   └── creates remote-state S3 bucket
          ↓
shared (tikto/shared/terraform.tfstate)
   ├── dev  (tikto/dev/terraform.tfstate)
   └── prod (tikto/prod/terraform.tfstate)
```

Dev and Prod read only the exported shared outputs. They never share an application state file or DynamoDB table.

Every remote stack contains:

| File | Purpose |
| --- | --- |
| `versions.tf` | Terraform/provider constraints and S3 backend declaration |
| `providers.tf` | AWS region and default tags |
| `variables.tf` | Supported configuration contract |
| `main.tf` | Module composition and resources |
| `outputs.tf` | Values used by operators, CI or another stack |
| `backend.hcl.example` | State bucket/key template |
| `terraform.tfvars.example` | Safe input template without secrets |

## `bootstrap`

Creates the S3 backend bucket with versioning, encryption, public access blocking and `prevent_destroy`. It intentionally uses local state.

```powershell
Set-Location Infrastructure/environments/bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
# Set a globally unique state_bucket_name.

terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output state_bucket_name
```

## `shared`

Creates:

- One VPC across three AZs.
- Three public and three private subnets.
- Internet Gateway and one NAT Gateway by default.
- ECR repositories `tikto/backend` and `tikto/notification`.
- GitHub OIDC provider, image build role and read-only Terraform plan role.

Public subnets serve Dev Fargate/ALB. Private subnets serve Prod EKS. The subnets are tagged for AWS Load Balancer Controller discovery.

```powershell
Set-Location Infrastructure/environments/shared
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

The `terraform_state_bucket_name` variable must equal the bucket in `backend.hcl`; it scopes the GitHub plan role to the correct state prefix.

## `dev`

Reads the shared VPC, public subnets and GitHub OIDC provider from shared state, then creates:

```text
CloudFront
├── /*       → private S3 frontend
└── /api/*   → public ALB restricted to CloudFront
                    ↓
             ECS backend:3000
                    ↓ Service Connect
             ECS notification:8000

Backend task role → Dev DynamoDB
```

The Fargate tasks use public egress to avoid an additional NAT path. Their security group accepts traffic only from the ALB.

```powershell
Set-Location Infrastructure/environments/dev
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan

$url = terraform output -raw application_url
Invoke-RestMethod "$url/api/health"
Invoke-RestMethod "$url/api/runtime"
Invoke-RestMethod "$url/api/status"
```

## `prod`

Reads the shared VPC and private subnets, then always creates:

- Production DynamoDB with PITR and deletion protection.
- EKS cluster, encrypted Spot node group and managed add-ons.
- Application and AWS Load Balancer Controller Pod Identity roles.
- ADOT and Fluent Bit Pod Identity roles.
- CloudWatch Container Insights log groups, dashboard and alarms.

### Phase 1: platform

Set `enable_edge = false`, apply the stack, configure kubectl and bootstrap Argo CD. GitOps owns Kubernetes manifests and must install AWS Load Balancer Controller, ADOT and Fluent Bit using these service accounts:

| Namespace | Service account | AWS access |
| --- | --- | --- |
| `tikto-prod` | `tikto-app` | Production DynamoDB table |
| `kube-system` | `aws-load-balancer-controller` | ALB reconciliation |
| `observability` | `otel-collector` | Container Insights metrics/performance logs |
| `observability` | `fluent-bit` | Application CloudWatch log group |

```powershell
Set-Location Infrastructure/environments/prod
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan

Invoke-Expression (terraform output -raw kubectl_config_command)
kubectl get nodes
```

### Phase 2: edge

GitOps must first create an internal Application Load Balancer named `tikto-prod-api`. Then set:

```hcl
enable_edge          = true
frontend_bucket_name = "your-unique-tikto-prod-frontend"
```

Apply the same stack again. Terraform adds the CloudFront VPC Origin, private frontend bucket, distribution and ALB ingress rule. When `enable_edge=false`, edge outputs return `null` and Terraform performs no ALB lookup.

## Safe change process

```powershell
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Stop if a plan unexpectedly replaces the shared VPC, EKS cluster, DynamoDB table or CloudFront distribution. Because Dev and Prod use one VPC, replacing the shared network affects both environments.
