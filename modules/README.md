# Terraform modules

Module là khối hạ tầng tái sử dụng. Không chạy `terraform apply` trực tiếp trong các thư mục module vì chúng không khai báo provider/backend và thường còn thiếu input bắt buộc. Hãy chạy root stack trong `../environments`.

## Danh mục

| Module | Vai trò | Được dùng bởi |
| --- | --- | --- |
| `network` | VPC, subnets, routes, IGW, NAT tùy chọn | Shared |
| `dynamodb` | Bảng dữ liệu tasks/events | Dev, prod |
| `ecr` | Container repositories và lifecycle | Shared |
| `ecs-application` | Backend + notification trên Fargate, ALB, Service Connect | Dev |
| `eks-platform` | EKS, node group, add-ons và application Pod Identity | Prod |
| `eks-observability` | CloudWatch, ADOT/Fluent Bit Pod Identity, dashboard và alarms | Prod |
| `frontend-edge` | S3 frontend, OAC, CloudFront và `/api/*` routing | Dev, prod |
| `cloudfront-vpc-origin` | Kết nối CloudFront với private ALB | Prod phase 2 |
| `github-oidc-role` | IAM role cho GitHub Actions không cần access key | Shared, dev |

Mỗi module thường có:

```text
variables.tf → hợp đồng đầu vào
main.tf      → resources/data sources
outputs.tf   → giá trị trả về cho module gọi nó
```

## `network`

### Mục đích

Tạo network foundation dùng chung cho ECS hoặc EKS:

```text
VPC
├── Internet Gateway
├── Public subnet mỗi AZ
│   └── route 0.0.0.0/0 → IGW
└── Private subnet mỗi AZ
    └── optional route 0.0.0.0/0 → NAT
```

Module cũng khóa default security group và gắn Kubernetes subnet discovery tags khi có `kubernetes_cluster_name`.

### Tài nguyên chính

- `aws_vpc`
- `aws_internet_gateway`
- `aws_subnet.public/private`
- `aws_route_table.public/private`
- `aws_eip` và `aws_nat_gateway` tùy chế độ
- `aws_default_security_group` không có ingress/egress mặc định

### Input quan trọng

| Input | Ý nghĩa |
| --- | --- |
| `name` | Prefix tên tài nguyên. |
| `vpc_cidr` | CIDR toàn VPC. |
| `availability_zones` | Danh sách AZ; tối thiểu hai. |
| `public_subnet_cidrs` | Một CIDR public cho mỗi AZ. |
| `private_subnet_cidrs` | Một CIDR private cho mỗi AZ. |
| `nat_gateway_mode` | `none`, `single`, hoặc `one_per_az`. |
| `kubernetes_cluster_name` | Nếu có, module gắn tag discovery cho AWS Load Balancer Controller. |

### NAT modes

| Mode | Chi phí | Khả dụng | Dùng khi |
| --- | --- | --- | --- |
| `none` | Thấp nhất | Private subnet không có Internet egress | Dev Fargate đang chạy ở public subnet hoặc workload chỉ dùng VPC endpoints |
| `single` | Một NAT/giờ | NAT lỗi/AZ lỗi có thể ảnh hưởng toàn bộ private egress | Lab hoặc portfolio production |
| `one_per_az` | Cao nhất | Zonal HA | Production thật |

### Output

- `vpc_id`, `vpc_cidr`
- `internet_gateway_id`
- `public_subnet_ids`
- `private_subnet_ids`
- `nat_gateway_ids`

## `dynamodb`

### Mục đích

Tạo bảng phù hợp với implementation trong `BE/src/store.mjs`:

```text
Partition key: scope (String)
Sort key:      id    (String)
Billing:       PAY_PER_REQUEST
Encryption:    AWS-owned key
```

Backend tạo scope theo môi trường và collection, ví dụ `prod#tasks`.

### Input quan trọng

| Input | Dev | Prod |
| --- | --- | --- |
| `name` | `tikto-dev-app` | `tikto-prod-app` |
| `point_in_time_recovery` | `false` | `true` |
| `deletion_protection` | `false` | `true` |

### Output

- `name`: đưa vào `DYNAMODB_TABLE`.
- `arn`: dùng tạo least-privilege task role/Pod Identity policy.

## `ecr`

### Mục đích

Tạo nhiều ECR repositories bằng `for_each`. Shared stack hiện tạo:

```text
tikto/backend
tikto/notification
```

### Cấu hình

- Immutable tags: không thể đẩy lại một tag release đã tồn tại.
- Scan on push.
- AES-256 encryption.
- Untagged images hết hạn sau 7 ngày.
- Giữ mặc định 30 tagged images gần nhất với prefix `sha-` hoặc `v`.

CI nên dùng tag bất biến:

```text
sha-a4f28c1
v1.2.0
```

Không dùng `latest` trong Task Definition hoặc Kubernetes manifest.

### Output

- `repository_urls`: dùng khi build/push và tạo image URI.
- `repository_arns`: dùng giới hạn GitHub build role.

## `ecs-application`

### Mục đích

Triển khai application development trên ECS Fargate:

```text
CloudFront
   ↓ HTTP từ managed prefix list
Internet-facing ALB:80
   ↓ security-group reference
Backend Fargate task:3000
   ↓ ECS Service Connect
Notification Fargate task:8000
```

### Tài nguyên chính

- ECS cluster và Cloud Map HTTP namespace.
- Hai task definitions.
- Hai ECS services.
- Application Load Balancer, listener và IP target group.
- ECS Service Connect endpoint `notification:8000`.
- Execution role dùng pull ECR/write logs.
- Backend task role chỉ được đọc/ghi đúng DynamoDB table.
- Notification task role không có DynamoDB permission.
- CloudWatch log group riêng cho từng service.
- Security group riêng cho ALB và tasks.

### Task Definition backend

Module cấu hình tự động:

```text
PORT=3000
APP_ENV=<environment>
APP_VERSION=<version>
IMAGE_TAG=<git SHA>
STORE_BACKEND=dynamodb
DYNAMODB_TABLE=<table name>
AWS_REGION=<region>
NOTIFICATION_SERVICE_URL=http://notification:8000
```

Health check container và ALB cùng gọi `/api/health`.

### Task Definition notification

```text
PORT=8000
health=/health
```

Notification hiện lưu state trong memory, do đó mặc định chỉ một replica.

### Rolling deployment

Hai ECS services dùng:

```text
minimumHealthyPercent = 100
maximumPercent        = 200
circuitBreaker        = enabled + rollback
```

ECS khởi động task mới, chờ healthy rồi mới drain task cũ. Nếu không đạt steady state, ECS rollback service revision.

### Input quan trọng

| Input | Ý nghĩa |
| --- | --- |
| `backend_image` | Image URI đầy đủ, có immutable tag/digest. |
| `notification_image` | Notification image URI. |
| `backend_image_tag` | SHA hiển thị ở `/api/runtime`. |
| `dynamodb_table_name/arn` | Runtime config và IAM policy. |
| `subnet_ids` | Dev truyền public subnets để tránh NAT. |
| `assign_public_ip` | Chỉ cung cấp egress; SG vẫn chặn public inbound. |
| `capacity_provider` | `FARGATE` hoặc `FARGATE_SPOT`. |
| `backend_environment` | Non-secret overrides bổ sung. |

### Output

- ECS cluster/service names và ARNs.
- ALB ARN/DNS cho CloudFront origin.
- Task/execution role ARNs cho GitHub deploy role.

## `eks-platform`

### Mục đích

Tạo production Kubernetes platform; application manifests vẫn do Argo CD quản lý.

### Tài nguyên chính

- EKS cluster.
- CloudWatch control-plane log group.
- KMS key cho Kubernetes Secrets.
- Encrypted gp3 launch template.
- Spot managed node group.
- EKS add-ons:
  - CoreDNS
  - kube-proxy
  - VPC CNI
  - EKS Pod Identity Agent
- Application và ALB Controller Pod Identity roles/associations.

### Pod Identity

| Namespace/service account | AWS quyền |
| --- | --- |
| `tikto-prod/tikto-app` | DynamoDB table cụ thể |
| `kube-system/aws-load-balancer-controller` | Tạo/quản lý ALB, target group và SG |

Role trust `pods.eks.amazonaws.com`; không có static AWS key hoặc service-account annotation kiểu IRSA.

### Networking

- Nodes chạy trong private subnets.
- EKS private endpoint luôn bật.
- Public endpoint chỉ bật nếu `cluster_public_access_cidrs` không rỗng.
- Không đặt CIDR `0.0.0.0/0`; dùng VPN/operator IP `/32`.

### Input quan trọng

| Input | Mặc định production |
| --- | --- |
| `kubernetes_version` | `1.36` từ environment |
| `node_capacity_type` | `SPOT` |
| `node_min/desired/max_size` | `2/2/4` |
| `node_instance_types` | `t3a.medium`, `t3.medium` |
| `node_disk_size` | 30 GiB |
| `enable_secrets_encryption` | `true` |
| `control_plane_log_types` | Toàn bộ năm loại log |

### Module không làm gì?

Module không cài Argo CD, Helm charts hoặc application manifests. Đây là bootstrap/deployment layer chạy sau khi EKS tồn tại. Việc tách này tránh Terraform và Argo CD cùng tranh quyền quản lý Kubernetes resources.

### Output

- Cluster name, ARN, endpoint và CA.
- Node role.
- Application và ALB Controller Pod Identity role ARNs.

## `eks-observability`

### Mục đích

Tạo phần AWS observability cho EKS production, trong khi Argo CD vẫn sở hữu ADOT/Fluent Bit manifests trong cluster.

### Tài nguyên chính

- CloudWatch log groups `/application` và `/performance`, giữ mặc định 30 ngày.
- Pod Identity role `otel-collector` chỉ ghi Container Insights metrics/performance logs.
- Pod Identity role `fluent-bit` chỉ ghi application logs.
- CloudWatch dashboard cho node CPU/memory, pod count/restarts và recent errors.
- Alarms cho node CPU, node memory và failed nodes.

`alarm_actions` nhận danh sách SNS topic ARN; để rỗng thì alarm vẫn đánh giá nhưng không gửi notification. Module chưa cấp X-Ray permission vì application tracing chưa nằm trong giai đoạn này.

### Output

- ADOT và Fluent Bit role ARNs.
- Application/performance log group names.
- CloudWatch dashboard name.

## `frontend-edge`

### Mục đích

Phục vụ Vite SPA và API trên cùng domain:

```text
CloudFront
├── default behavior /*
│   └── private S3 qua Origin Access Control
└── ordered behavior /api/*
    └── public ALB custom origin hoặc private VPC origin
```

### S3 configuration

- Public access bị chặn hoàn toàn.
- Bucket-owner-enforced ownership.
- AES-256 encryption.
- Versioning.
- Non-current versions hết hạn sau 30 ngày.
- Bucket policy chỉ cho đúng CloudFront distribution đọc object.

### CloudFront configuration

- Redirect HTTP sang HTTPS.
- Brotli/Gzip.
- `/api/*` tắt cache và forward viewer headers trừ `Host`.
- AWS managed security response headers.
- CloudFront Function rewrite extensionless SPA paths về `/index.html`.
- Không rewrite lỗi API thành HTML.
- Custom domain/Route53 là optional.

### Cache contract với CI

```text
assets có content hash → Cache-Control: max-age=31536000, immutable
index.html              → Cache-Control: no-cache,no-store,must-revalidate
```

### `api_origin.type`

| Type | Dùng ở đâu | Config |
| --- | --- | --- |
| `custom` | Dev | CloudFront kết nối public ALB DNS |
| `vpc` | Prod | CloudFront dùng `vpc_origin_id` để vào internal ALB |

### Output

- Frontend bucket name.
- CloudFront ID/ARN/domain.
- `application_url` dùng cho smoke test.

## `cloudfront-vpc-origin`

### Mục đích

Bao bọc resource `aws_cloudfront_vpc_origin`, kết nối CloudFront với origin nằm trong private subnet.

Production truyền ARN của internal ALB `tikto-prod-api`. Module đang dùng:

```text
http_port              = 80
https_port             = 443
origin_protocol_policy = http-only
TLS protocols          = TLSv1.2
```

VPC phải có Internet Gateway gắn vào VPC theo yêu cầu của CloudFront VPC Origin, dù traffic đến origin dùng kết nối private do AWS quản lý.

Module có timeout create/delete 20 phút vì CloudFront provisioning không tức thời.

### Output

- VPC Origin ID cho block `vpc_origin_config` của distribution.
- VPC Origin ARN.

## `github-oidc-role`

### Mục đích

Tạo IAM role mà GitHub Actions assume qua OIDC, không lưu:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

### Trust policy

Role kiểm tra đồng thời:

```text
aud = sts.amazonaws.com
sub matches một trong subjects được truyền vào
```

Ví dụ subject:

```text
repo:ORG/REPO:ref:refs/heads/main
repo:ORG/REPO:environment:dev
repo:ORG/REPO:environment:prod
```

GitHub repositories mới có thể dùng immutable owner/repository IDs; lấy subject thật từ GitHub OIDC claim thay vì đoán.

### Input

| Input | Ý nghĩa |
| --- | --- |
| `oidc_provider_arn` | Provider được shared stack tạo. |
| `subjects` | Danh sách workflow/ref/environment được phép. |
| `policy_json` | Quyền của role; module gọi phải tạo least-privilege policy. |

Shared dùng module cho build role chỉ push ECR. Dev dùng module cho deploy role chỉ update ECS services, frontend bucket và distribution thuộc dev.

## Cách thêm module mới

1. Tạo thư mục `modules/<name>`.
2. Khai báo input có description và validation trong `variables.tf`.
3. Đặt resources trong `main.tf`.
4. Chỉ export giá trị caller thật sự cần trong `outputs.tf`.
5. Không khai báo provider/backend bên trong reusable module.
6. Gọi module từ environment thích hợp.
7. Chạy:

```powershell
terraform fmt -recursive Infrastructure
terraform -chdir=Infrastructure/environments/dev validate
terraform -chdir=Infrastructure/environments/prod validate
```
