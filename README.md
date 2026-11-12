# TikTo Infrastructure · Terraform

Repo này dựng hạ tầng AWS cho TikTo Calendar ở Sydney (`ap-southeast-2`). Dev và Prod dùng chung một cụm EKS. Mỗi môi trường có namespace, Application Load Balancer (ALB) và bảng DynamoDB riêng. Argo CD đọc chart từ [repo Manifest](https://github.com/tikto-calender/manifest) để triển khai ứng dụng lên cụm.

## Chuẩn bị

- Terraform 1.10 trở lên, AWS CLI v2, kubectl và Helm.
- AWS credentials cho đúng tài khoản và một bucket S3 đã tồn tại để lưu Terraform state.
- Clone hai repo cạnh nhau để các đường dẫn `../manifest` bên dưới hoạt động.

**Linux/macOS và Windows PowerShell**

```sh
git clone https://github.com/tikto-calender/infra.git
git clone https://github.com/tikto-calender/manifest.git
cd infra
```

Nếu đã có mã nguồn, mở terminal ở thư mục gốc repo Terraform.

## 1. Tạo cấu hình và xem plan

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

Điền tên bucket vào `backend.hcl`, rồi xem lại vùng AWS, mạng và cấu hình node trong `terraform.tfvars`. Với hạ tầng đang chạy, dùng đúng bucket và state key của lần triển khai trước. Giữ `project_name = "tikto"` để khớp với tên target group và bảng DynamoDB mặc định trong Manifest. Bật `enable_dev_edge` và `enable_edge` để dùng cả hai ALB.

**Linux/macOS**

```sh
state_bucket='tikto-terraform-state' # Thay bằng bucket trong backend.hcl.
aws sts get-caller-identity
aws s3api head-bucket --bucket "$state_bucket" --region ap-southeast-2
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=platform.tfplan && terraform show platform.tfplan
```

**Windows PowerShell**

```powershell
$stateBucket = 'tikto-terraform-state' # Thay bằng bucket trong backend.hcl.
aws sts get-caller-identity
aws s3api head-bucket --bucket $stateBucket --region ap-southeast-2
terraform init '-backend-config=backend.hcl'
terraform validate
terraform plan '-out=platform.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan thất bại.' }
terraform show platform.tfplan
```

Kiểm tra đúng tài khoản và state trước khi apply. Nếu plan thay thế VPC, EKS hoặc bảng Prod, dừng lại để kiểm tra nguyên nhân. Nếu CloudFormation đang quản lý tài nguyên trùng tên, cần chuyển quyền quản lý hoặc dùng tên dự án và tài nguyên riêng.

Để chỉ kiểm tra cấu hình trong một checkout mới, cả hai hệ điều hành dùng `terraform init -backend=false -input=false`, `terraform validate` và `terraform fmt -check -recursive`. GitHub Actions chạy các kiểm tra này trong workflow **Terraform validate**.

## 2. Apply và kết nối EKS

Sau khi đã duyệt plan, chạy các lệnh sau. Bước apply tạo tài nguyên có tính phí trên AWS.

**Linux/macOS**

```sh
terraform apply platform.tfplan
cluster=$(terraform output -raw cluster_name)
vpc=$(terraform output -raw vpc_id)
aws eks update-kubeconfig --region ap-southeast-2 --name "$cluster"
kubectl get nodes
```

**Windows PowerShell**

```powershell
terraform apply platform.tfplan
$cluster = terraform output -raw cluster_name
$vpc = terraform output -raw vpc_id
aws eks update-kubeconfig --region ap-southeast-2 --name $cluster
kubectl get nodes
```

Dùng IAM identity đã tạo cluster hoặc một role đã khai báo trong `eks_admin_role_arns`. Nếu dùng AWS CLI profile, truyền đúng `--profile` khi cập nhật kubeconfig.

<a name="2-bootstrap-controllers-and-gitops"></a>

## 3. Cài controller và triển khai ứng dụng

Giữ terminal đã đặt `cluster` và `vpc` ở bước trên. Kiểm tra context Kubernetes trỏ vào EKS vừa tạo. Các lệnh dưới đây dùng được trên **Linux/macOS và Windows PowerShell**.

```sh
kubectl config current-context
kubectl apply -f ../manifest/bootstrap/namespaces.yaml
helm repo add eks https://aws.github.io/eks-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --namespace kube-system --version 1.14.0 --wait --set "clusterName=$cluster" --set "region=ap-southeast-2" --set "vpcId=$vpc" --set "serviceAccount.name=aws-load-balancer-controller"
helm upgrade --install argocd argo/argo-cd --namespace argocd --version 9.4.0 --wait --timeout 10m -f ../manifest/bootstrap/argocd-values.yaml
kubectl wait --for=condition=Established crd/targetgroupbindings.elbv2.k8s.aws --timeout=120s
kubectl -n argocd get pods
```

AWS Load Balancer Controller đăng ký IP của pod vào target group. Sau khi các image GHCR đã có digest hợp lệ trên `manifest/main`, làm theo [bước deploy của Manifest](https://github.com/tikto-calender/manifest#deploy-with-argo-cd). Nếu repo Manifest là private, cấu hình quyền đọc trong Argo CD trước khi tạo Application. Khi nâng phiên bản controller, xem yêu cầu nâng cấp CRD của chart đang dùng.

Để cập nhật digest Dev từ repo ứng dụng, cấp `GITOPS_TOKEN` quyền ghi Manifest. Các image GHCR hiện được kéo ẩn danh. Để promote, cấp Manifest quyền **Write** trên package tương ứng. Với Backend blue/green, điền `preview_runner_cidrs` và `github_oidc_provider_arn` trước khi apply, rồi dùng Terraform outputs để cấu hình [GitHub Environment `prod` của Manifest](https://github.com/tikto-calender/manifest#configure-backend-bluegreen).

## 4. Kiểm tra Dev và Prod

Khi Argo CD báo `Synced` và `Healthy`, lấy URL từ Terraform outputs. Ví dụ kiểm tra Dev bên dưới. Với Prod, dùng output `application_url` thay cho `dev_application_url`.

**Linux/macOS**

```sh
url=$(terraform output -raw dev_application_url)
curl -fsS -o /dev/null -w '%{http_code}\n' "$url/"
curl -fsS "$url/api/health"
curl -fsS "$url/api/status"
```

**Windows PowerShell**

```powershell
$url = terraform output -raw dev_application_url
(Invoke-WebRequest -UseBasicParsing "$url/").StatusCode
Invoke-RestMethod "$url/api/health"
Invoke-RestMethod "$url/api/status"
```

Trang web phải trả HTTP 200. `/api/health` phải báo `ok`. `/api/status` cho biết Backend có đọc được DynamoDB và gọi được Notification Service hay không. ALB chuyển `/api` đến Backend và các đường dẫn khác đến Frontend trên cùng hostname.

## Khi nâng cấp hạ tầng cũ

- Giữ đúng state key của Prod. Các stack ECS Dev và Shared cũ cần được quản lý bằng cấu hình và state tương ứng. Kiểm tra dữ liệu Dev trước khi chuyển sang bảng `tikto-dev-eks-app`.
- Nếu control plane còn dùng private subnet sắp bị xóa, chuyển giao diện mạng sang các subnet sẽ giữ lại trước. Kiểm tra riêng các thay đổi liên quan CloudFront hoặc bucket Frontend cũ trong plan.
- Nếu state còn node group `system`, lấy thông số bằng `aws eks describe-nodegroup --region ap-southeast-2 --cluster-name tikto-prod-eks --nodegroup-name system` và điền `legacy_node_group`. Plan chuyển đổi phải giữ `system` và tạo `system-v2`. Chờ node mới `Ready`, cordon và drain node cũ từng máy. Sau khi workload đã chuyển xong, bỏ `legacy_node_group` rồi duyệt plan mới.
- Dev và Prod chia sẻ CPU và RAM của cùng một cụm. Trước khi chuyển lưu lượng, kiểm tra pod `Pending`, sức chứa node và số liệu CloudWatch. Lịch sử Notification Service nằm trong RAM của pod.
