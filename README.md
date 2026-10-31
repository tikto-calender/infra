# TikTo AWS Infrastructure

Terraform infrastructure is split into one bootstrap prerequisite and three operational stacks:

| Stack | State key | Owns |
| --- | --- | --- |
| `bootstrap` | Local state | Versioned and encrypted S3 state bucket |
| `shared` | `tikto/shared/terraform.tfstate` | Shared VPC, subnets, NAT, ECR and GitHub OIDC roles |
| `dev` | `tikto/dev/terraform.tfstate` | DynamoDB Dev, ECS Fargate, public ALB, frontend S3/CloudFront |
| `prod` | `tikto/prod/terraform.tfstate` | DynamoDB Prod, EKS, observability and optional production edge |

`bootstrap` is not an application stack. It runs once because an S3 backend cannot create its own bucket.

## Architecture

```text
                         shared state
                              │
              ┌───────────────┴────────────────┐
              │                                │
        public subnets                   private subnets
              │                                │
Dev CloudFront → ALB → ECS              EKS production
              │                                ├── DynamoDB via Pod Identity
              └── DynamoDB via task role       └── ADOT/Fluent Bit → CloudWatch

Prod phase 2:
CloudFront → VPC Origin → internal ALB created by GitOps → EKS
```

Both environments share one VPC. Security groups and IAM roles isolate workloads, but deleting the shared VPC affects both environments.

## Repository layout

```text
Infrastructure/
├── .github/workflows/terraform-plan.yml
├── environments/
│   ├── bootstrap/
│   ├── shared/
│   ├── dev/
│   └── prod/
└── modules/
    ├── network/
    ├── dynamodb/
    ├── ecr/
    ├── ecs-application/
    ├── eks-platform/
    ├── eks-observability/
    ├── frontend-edge/
    ├── cloudfront-vpc-origin/
    └── github-oidc-role/
```

- [Environment configuration and commands](environments/README.md)
- [Module responsibilities, inputs and outputs](modules/README.md)

## Defaults

| Setting | Value |
| --- | --- |
| Region | `ap-southeast-1` |
| Shared VPC | `10.20.0.0/16`, three AZs |
| Public subnets | `10.20.0.0/24` through `10.20.2.0/24` |
| Private subnets | `10.20.10.0/24` through `10.20.12.0/24` |
| NAT | One NAT Gateway; use `one_per_az` for zonal HA |
| Development | ECS Fargate in public subnets with restrictive security groups |
| Production | EKS private Spot nodes, desired/min/max `2/2/4` |
| Database | DynamoDB on-demand; production has PITR and deletion protection |
| Monitoring | CloudWatch logs, Container Insights dashboard and alarms |

No application AWS access key is stored. ECS uses task roles and EKS uses Pod Identity. Secrets Manager is intentionally absent until the application has a real password or API token.

## Deployment order

### 1. Bootstrap state storage

```powershell
Set-Location Infrastructure/environments/bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output state_bucket_name
```

Keep the bootstrap local state in a secure operator backup. The bucket has versioning, AES-256 encryption, public access blocking and `prevent_destroy`.

### 2. Shared foundation

Copy the state bucket name into both `backend.hcl` and `terraform.tfvars`:

```powershell
Set-Location ../shared
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Shared must be applied before Dev or Prod because they read its VPC, subnet and OIDC outputs through `terraform_remote_state`.

### 3. Development

Set immutable backend/notification image URIs and a globally unique frontend bucket:

```powershell
Set-Location ../dev
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan

$url = terraform output -raw application_url
Invoke-RestMethod "$url/api/health"
Invoke-RestMethod "$url/api/runtime"
```

Dev Fargate tasks receive public IPs for egress but accept no public inbound traffic. The ALB only accepts the AWS-managed CloudFront origin-facing prefix list.

### 4. Production phase 1

Keep `enable_edge = false` for the first apply:

```powershell
Set-Location ../prod
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan

$configure = terraform output -raw kubectl_config_command
Invoke-Expression $configure
kubectl get nodes
```

This phase creates EKS, DynamoDB, Pod Identity roles, Container Insights log groups, dashboard and alarms. Argo CD then installs AWS Load Balancer Controller, ADOT and Fluent Bit.

The GitOps production Ingress must create a stable internal ALB:

```yaml
alb.ingress.kubernetes.io/load-balancer-name: tikto-prod-api
alb.ingress.kubernetes.io/scheme: internal
alb.ingress.kubernetes.io/target-type: ip
```

### 5. Production phase 2

After `tikto-prod-api` is active, update `terraform.tfvars`:

```hcl
enable_edge         = true
frontend_bucket_name = "your-unique-tikto-prod-frontend"
```

Then run another plan and apply in the same `prod` stack:

```powershell
terraform plan -out=tfplan
terraform apply tfplan
terraform output application_url
```

This creates the CloudFront VPC Origin and routes `/api/*` privately to the internal ALB. It does not create a second Terraform state.

## GitHub Actions plan workflow

[terraform-plan.yml](.github/workflows/terraform-plan.yml) provides:

- Pull requests: `terraform fmt -check` and `terraform validate` without AWS credentials.
- Manual dispatch: GitHub OIDC authentication and ordered plans `shared → dev → prod`.
- Job Summary counts for create, update, delete and replace actions.
- Readable plan artifacts retained for five days; binary plans are not uploaded.
- No automatic apply.

Create a GitHub Environment named `infrastructure-plan` with:

| Variable | Content |
| --- | --- |
| `AWS_REGION` | `ap-southeast-1` |
| `AWS_TERRAFORM_PLAN_ROLE_ARN` | Shared output `github_terraform_plan_role_arn` |
| `TF_STATE_BUCKET` | Bootstrap output `state_bucket_name` |
| `SHARED_TFVARS_JSON` | Shared stack inputs as a JSON object |
| `DEV_TFVARS_JSON` | Dev stack inputs as a JSON object |
| `PROD_TFVARS_JSON` | Prod stack inputs as a JSON object |

Because the plan job uses the `infrastructure-plan` GitHub Environment, the shared input must trust the matching OIDC subject:

```json
{
  "terraform_state_bucket_name": "your-tikto-terraform-state",
  "github_build_oidc_subjects": [
    "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
  ],
  "github_plan_oidc_subjects": [
    "repo:YOUR_ORG/YOUR_REPO:environment:infrastructure-plan"
  ]
}
```

Example production input:

```json
{
  "terraform_state_bucket_name": "your-tikto-terraform-state",
  "cluster_public_access_cidrs": ["203.0.113.10/32"],
  "enable_edge": false
}
```

Run `bootstrap` and the first `shared` apply locally with AWS SSO. Then save the shared plan-role output in GitHub. The role has AWS `ReadOnlyAccess` plus state read/lock permissions, but no infrastructure mutation permission.

## Validation

```powershell
terraform fmt -check -recursive Infrastructure
terraform -chdir=Infrastructure/environments/bootstrap validate
terraform -chdir=Infrastructure/environments/shared validate
terraform -chdir=Infrastructure/environments/dev validate
terraform -chdir=Infrastructure/environments/prod validate
```

Always review plans containing `delete` or `replace`. Production DynamoDB deletion protection intentionally blocks accidental table destruction.
