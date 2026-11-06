# TikTo AWS Infrastructure

Terraform for TikTo's development and production environments in AWS Sydney (`ap-southeast-2`).

| Stack | Owns |
| --- | --- |
| [Shared](shared/main.tf) | ECR repositories for Backend and Notification, the GitHub OIDC provider, and IAM roles for image publishing and Terraform plans |
| [Development](dev/main.tf) | A dedicated VPC, ECS Fargate services, public ALB, DynamoDB, S3 frontend, and CloudFront |
| [Production](prod/main.tf) | A dedicated VPC, EKS with managed worker nodes, DynamoDB, CloudWatch, and the S3 and CloudFront edge. Kubernetes Ingress provisions the public ALB. |

The stacks use separate state keys in the existing S3 bucket `tikto-terraform-state`. Dev and Prod read the GitHub OIDC provider ARN from Shared. For the inputs, resources, and outputs of each reusable component, see the [module catalog](modules/README.md).

## Initial deployment

Use Terraform 1.10 or newer and AWS credentials for the target account. From this repository's root, copy each stack's `terraform.tfvars.example` to `terraform.tfvars` and `backend.hcl.example` to `backend.hcl` if the local files do not already exist. Fill in the environment values. The backend config selects the S3 state location at init time. If you customize that location, make sure Dev and Prod read the same Shared bucket, region, and key that Shared uses.

For a working directory initialized with the previous inline backend, run init with `-reconfigure` after verifying that `backend.hcl` points to the same existing state object. Review each saved plan before applying it.

### 1. Shared

Verify the state bucket and the GitHub OIDC subjects for the build and plan roles. Apply Shared first so that Dev and Prod can read its outputs and the application pipelines can publish images to ECR.

```sh
terraform -chdir=shared init -backend-config=backend.hcl
terraform -chdir=shared plan -out=local.tfplan
terraform -chdir=shared apply local.tfplan
```

### 2. Development

Set the Backend and Notification image URIs to published ECR images and choose a unique frontend bucket name. The public ALB sends API traffic to Backend on port `3000`. Backend calls Notification on port `8000` through ECS Service Connect.

```sh
terraform -chdir=dev init -backend-config=backend.hcl
terraform -chdir=dev plan -out=local.tfplan
terraform -chdir=dev apply local.tfplan
terraform -chdir=dev output -raw application_url
```

Use the application URL to check `/api/health` after deployment. Terraform creates the initial ECS task definitions. Backend CD registers and deploys later revisions, so changes to task settings require rolling out the corresponding revision.

### 3. Production

1. Apply `prod` with `enable_edge = false` to create EKS, DynamoDB, and CloudWatch. If you administer EKS through its public endpoint, replace the example CIDR with your actual operator CIDR.
2. Run the command from `terraform -chdir=prod output -raw kubectl_config_command`. Install the AWS Load Balancer Controller using the `kube-system/aws-load-balancer-controller` service account, then deploy the [Kubernetes manifests](https://github.com/tikto-calender/manifest) with published ECR images. Backend uses the `tikto-prod/tikto-app` service account for DynamoDB access.
3. Wait for the Ingress to provision `tikto-prod-api` with the `tikto-prod-cloudfront-origin` security group. Set `enable_edge = true` and a unique `frontend_bucket_name`, then plan and apply Prod again to create the frontend bucket and CloudFront distribution.

```sh
terraform -chdir=prod init -backend-config=backend.hcl
terraform -chdir=prod plan -out=local.tfplan
terraform -chdir=prod apply local.tfplan
```

## CI/CD

The [Terraform workflow](.github/workflows/terraform-plan.yml) checks formatting and validates the root stacks on infrastructure pull requests. Run **Terraform validate and plan** manually to review changes against remote state. Apply approved plans separately.

Set the environment inputs in the GitHub `infrastructure-plan` environment. In addition to the existing inputs, `DEV_TFVARS_JSON` requires `network`, `assign_public_ip`, and `log_retention_days`. `PROD_TFVARS_JSON` requires `network`, `map_public_ip_on_launch`, and `log_retention_days`. Use the corresponding `terraform.tfvars.example` for the field names and current topology.

Application workflows use GitHub OIDC for AWS access. See each stack's `outputs.tf` for the role ARNs, ECS service names, bucket names, and CloudFront distribution IDs used by the [delivery workflows](https://github.com/tikto-calender/reusable-workflow).

If upgrading an existing deployment from the shared VPC layout, review all three plans for network or workload replacements before applying.
