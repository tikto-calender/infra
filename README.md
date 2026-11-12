# TikTo AWS Infrastructure (Terraform)

This repository provisions the AWS platform for TikTo Calendar. It creates one EKS cluster in Sydney and a separate DynamoDB table and Application Load Balancer (ALB) for each environment. Once the platform is ready, Argo CD deploys the application from [Manifest](https://github.com/tikto-calender/manifest).

## Prerequisites

- Terraform 1.10 or later, AWS CLI v2, kubectl and Helm 3. The examples use PowerShell from this repository's root.
- AWS credentials for the target account and an existing S3 bucket for Terraform state. Use `backend.hcl.example` for the backend settings and `terraform.tfvars.example` for the AWS resources.
- A checkout of [Manifest](https://github.com/tikto-calender/manifest) next to this repository, in a directory named `manifest`, for controller and workload setup.

To check the configuration locally before connecting to an AWS state backend, run:

```powershell
terraform init -backend=false -input=false
terraform validate
```

Run this check in a fresh checkout if the current directory is already initialized against S3. The **Terraform validate** workflow also checks formatting on GitHub.

## Platform layout

Three On-Demand `t3.medium` nodes, EKS control-plane network interfaces, and both ALBs use the same three public subnets. The nodes use public IPv4 and the Internet Gateway to reach GHCR. The Kubernetes API is reachable privately and from any public IPv4 address. EKS authenticates IAM identities and authorizes cluster access through its access configuration. Each public ALB sends /api requests to backend pods and serves all other paths from frontend pods on port 8080. Notification and Argo CD remain internal.

Dev and Prod share one Terraform configuration. For an existing deployment, keep the configured S3 state key `tikto/prod/terraform.tfstate`. To manage a legacy ECS Dev or Shared stack, use its previous configuration and matching state key.

## 1. Plan and apply the EKS platform

From the repository root in PowerShell, verify the AWS account. Create the local config files from the examples if needed. Set the state bucket in `backend.hcl` and review the settings in `terraform.tfvars`. Keep `enable_edge = true` and `enable_dev_edge = true` to use both public ALBs. If upgrading an existing stack that used CloudFront or a frontend S3 bucket, review any planned removals before applying.

Check which state owns any existing runtime and DynamoDB tables with the same names. A CloudFormation-managed runtime needs a separate project name or an ownership migration before Terraform can manage those resources.

Use `project_name = "tikto"` with the checked-in Helm environment values. If you change the project name, update their target group and DynamoDB names to match Terraform outputs.

If an existing cluster uses private subnets for its control-plane network interfaces, migrate those interfaces to the public subnets before removing the old subnets and their routes. Review a separate migration plan if Terraform proposes subnet deletions.

```powershell
aws sts get-caller-identity
if (-not (Test-Path 'backend.hcl')) { Copy-Item 'backend.hcl.example' 'backend.hcl' }
if (-not (Test-Path 'terraform.tfvars')) { Copy-Item 'terraform.tfvars.example' 'terraform.tfvars' }
```

After editing both files, verify the bucket in `backend.hcl` and review the plan:

```powershell
$stateBucket = 'tikto-terraform-state' # Use the bucket from backend.hcl.
aws s3api head-bucket --bucket $stateBucket --region ap-southeast-2
terraform init '-backend-config=backend.hcl'
terraform validate
terraform plan '-out=platform.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
terraform show platform.tfplan
```

If Terraform asks to reinitialize the backend, verify the existing S3 bucket and key before rerunning init with `-reconfigure`. Stop if the plan replaces the Prod VPC, cluster, or DynamoDB table. If `terraform state list` shows an existing `aws_eks_node_group.this` address, set `legacy_node_group` before applying. Copy `instanceTypes`, `capacityType`, and `scalingConfig` from `aws eks describe-nodegroup --cluster-name tikto-prod-eks --nodegroup-name system --region ap-southeast-2` into `instance_types`, `capacity_type`, `min_size`, `desired_size`, and `max_size`. Verify the new plan retains `system` and creates `system-v2`.

```powershell
terraform apply platform.tfplan
$cluster = terraform output -raw cluster_name
$vpc = terraform output -raw vpc_id
aws eks update-kubeconfig --region ap-southeast-2 --name $cluster
kubectl get nodes -L eks.amazonaws.com/nodegroup,topology.kubernetes.io/zone
```

Use the AWS identity that created the cluster, or list additional IAM role ARNs in `eks_admin_role_arns` to grant those roles cluster-wide administration through EKS access entries. An AWS CLI profile selects an identity. To use a named profile, add `--profile my-eks-profile` to `aws eks update-kubeconfig` and replace the name with your profile.

For a migration, wait for all three `system-v2` nodes to be Ready. Cordon all old nodes, then drain them one at a time with `kubectl drain NODE --ignore-daemonsets`. Review eviction blockers and workload health before proceeding. Remove `legacy_node_group` from local tfvars only after workload migration, then review a fresh plan that deletes the old group. Keep the old ECS Dev stack running if it still serves traffic. The new Dev table is `tikto-dev-eks-app`. Review any data migration before redirecting Dev traffic or retiring ECS.

## 2. Bootstrap controllers and GitOps

Use Helm 3 and kubectl from the `Infrastructure` directory. The commands assume the `manifest` checkout is a sibling directory. Publish the reusable workflow changes and the manifest Helm chart to their respective `main` branches before enabling the application workflows. After the AWS infrastructure apply, the Load Balancer Controller reconciles the `TargetGroupBinding` resources in Git and registers frontend and backend pod IPs in the existing target groups.

```powershell
$cluster = terraform output -raw cluster_name
$vpc = terraform output -raw vpc_id
aws eks update-kubeconfig --region ap-southeast-2 --name $cluster
kubectl get nodes

kubectl apply -f ../manifest/bootstrap/namespaces.yaml
helm repo add eks https://aws.github.io/eks-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system --version 1.14.0 --wait `
  --set "clusterName=$cluster" --set 'region=ap-southeast-2' --set "vpcId=$vpc" `
  --set 'serviceAccount.name=aws-load-balancer-controller'

helm upgrade --install argocd argo/argo-cd `
  --namespace argocd --version 9.4.0 --wait --timeout 10m `
  -f ../manifest/bootstrap/argocd-values.yaml

kubectl wait --for=condition=Established crd/targetgroupbindings.elbv2.k8s.aws --timeout=120s
kubectl -n argocd get pods
```

On controller upgrades, apply the CRDs from the pinned chart before upgrading if the upstream release requires it. To access Argo CD, use `kubectl -n argocd port-forward svc/argocd-server 8080:443`. If the manifest repo is private, configure Argo CD with read-only repository credentials first.

Publish the chart and both sets of environment values to `main` in `tikto-calender/manifest`. Argo CD tracks `main` and renders the same chart with separate Dev and Prod values. The GitOps workflows need permission to push image updates to that branch.

Make the `GITOPS_TOKEN` Actions secret available to the Frontend, Backend and Notification repos. Scope it to `tikto-calender/manifest` with Contents write for the Dev image updates. If you override `GITOPS_REPOSITORY`, update both the repository URL and source allowlist in the Argo manifests to match.

Merge qualifying application changes into `dev` to run **Deploy Dev**. Set the GHCR packages to **Public** for anonymous image pulls. Confirm the three Dev image files on manifest `main` point to pullable GHCR digests before applying the Dev Argo CD Application.

```powershell
kubectl apply -f ../manifest/bootstrap/dev.yaml
kubectl -n argocd get applications
kubectl -n argocd wait application/tikto-dev '--for=jsonpath={.status.sync.status}=Synced' --timeout=5m
kubectl -n argocd wait application/tikto-dev '--for=jsonpath={.status.health.status}=Healthy' --timeout=5m
kubectl -n tikto-dev rollout status deployment/backend
kubectl -n tikto-dev rollout status deployment/notification
kubectl -n tikto-dev rollout status deployment/frontend
```

When Dev is Synced and Healthy, check the running image digests. For the initial Prod deployment, confirm the Prod image files on manifest `main` point to pullable images, then apply `../manifest/bootstrap/prod.yaml`. Verify that Prod is Synced and Healthy and that the active Backend target group serves requests.

For subsequent releases, grant Manifest **Write** access in each GHCR package's **Manage Actions access** settings. To enable Backend blue/green promotion, set `preview_runner_cidrs` and `github_oidc_provider_arn` before applying the platform and configure Manifest's `prod` Environment from the Terraform outputs. [Promotion instructions](https://github.com/tikto-calender/manifest#promote-to-production)

## 3. Verify frontend and API through the ALB

Argo CD deploys the frontend Nginx container in both namespaces. Leave `VITE_API_ORIGIN` empty when building the image so browser requests use the same ALB hostname. The default ALB listener action forwards frontend traffic to port 8080. The `/api` and `/api/*` rules forward to backend pods on port 3000.

```powershell
kubectl -n tikto-dev get targetgroupbinding backend frontend
kubectl -n tikto-prod get targetgroupbinding backend backend-green frontend
terraform output frontend_target_group_names
$devUrl = terraform output -raw dev_application_url
$prodUrl = terraform output -raw application_url
(Invoke-WebRequest "$devUrl/").StatusCode
Invoke-RestMethod "$devUrl/api/health"
Invoke-RestMethod "$devUrl/api/status"
(Invoke-WebRequest "$prodUrl/").StatusCode
Invoke-RestMethod "$prodUrl/api/health"
Invoke-RestMethod "$prodUrl/api/status"
```

Expect HTTP 200 from each frontend and `status: ok` from each Backend health endpoint. Use `/api/status` to check DynamoDB and Notification Service. Push another Dev commit and confirm the new digest rolls out only in Dev before promoting it. Before cutover, check node allocatable resources, Pending pods, CloudWatch memory and CPU, and EC2 CPU credits. In a test window, drain one node, confirm the workloads fit on two nodes, and uncordon it afterward. Notification stores records in memory, so replacing its pod clears those records. The two environments share failure and capacity boundaries because they run on the same cluster.
