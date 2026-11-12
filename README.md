# TikTo Infrastructure (Terraform)

Provisions TikTo Calendar on AWS in Sydney (`ap-southeast-2`). Dev and Prod share one EKS cluster and each has its own load balancer and DynamoDB table. Argo CD deploys the app from [Manifest](https://github.com/tikto-calender/manifest).

You need Terraform 1.10+, AWS CLI v2 with credentials, an existing S3 state bucket, kubectl and Helm. Clone `manifest` beside this repository and run the commands below from the Terraform repository root.

## 1. Plan and apply

**Linux/macOS**

```sh
[ -f backend.hcl ] || cp backend.hcl.example backend.hcl
[ -f terraform.tfvars ] || cp terraform.tfvars.example terraform.tfvars
```

**Windows PowerShell**

```powershell
if (-not (Test-Path backend.hcl)) { Copy-Item backend.hcl.example backend.hcl }
if (-not (Test-Path terraform.tfvars)) { Copy-Item terraform.tfvars.example terraform.tfvars }
```

Set the S3 bucket and state key in `backend.hcl` and review `terraform.tfvars`. Keep `project_name = "tikto"` to match the default Manifest values. For existing infrastructure, use its current state and review planned deletions and replacements before applying.

**Both platforms**

```sh
aws sts get-caller-identity
terraform init '-backend-config=backend.hcl'
terraform validate
terraform plan '-out=platform.tfplan'
```

After the plan succeeds, inspect it with `terraform show platform.tfplan`. Apply the reviewed plan with `terraform apply platform.tfplan`.

## 2. Bootstrap controllers and GitOps

**Linux/macOS**

```sh
cluster=$(terraform output -raw cluster_name)
vpc=$(terraform output -raw vpc_id)
aws eks update-kubeconfig --region ap-southeast-2 --name "$cluster"
```

**Windows PowerShell**

```powershell
$cluster = terraform output -raw cluster_name
$vpc = terraform output -raw vpc_id
aws eks update-kubeconfig --region ap-southeast-2 --name $cluster
```

### Install controllers

With `cluster` and `vpc` set, verify the Kubernetes context and run these commands on **either platform**.

```sh
kubectl config current-context
kubectl get nodes
kubectl apply -f ../manifest/bootstrap/namespaces.yaml
helm repo add eks https://aws.github.io/eks-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --namespace kube-system --version 1.14.0 --wait --set "clusterName=$cluster" --set "region=ap-southeast-2" --set "vpcId=$vpc" --set "serviceAccount.name=aws-load-balancer-controller"
helm upgrade --install argocd argo/argo-cd --namespace argocd --version 9.4.0 --wait --timeout 10m -f ../manifest/bootstrap/argocd-values.yaml
kubectl wait --for=condition=Established crd/targetgroupbindings.elbv2.k8s.aws --timeout=120s
```

[Deploy the app with Manifest](https://github.com/tikto-calender/manifest#deploy-with-argo-cd). Open the URL from `terraform output -raw dev_application_url` or `terraform output -raw application_url` and check `/api/health` and `/api/status`.

For Backend blue/green, set `preview_runner_cidrs` and `github_oidc_provider_arn` before applying. [Backend release setup](https://github.com/tikto-calender/manifest#configure-backend-bluegreen)
