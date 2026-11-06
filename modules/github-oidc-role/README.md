# GitHub OIDC Role

Creates an IAM role that GitHub Actions can assume to obtain temporary AWS credentials. The caller supplies the OIDC provider ARN, permitted GitHub subjects, and the IAM policy for the role.

The trust policy controls which repositories, branches, or environments can assume the role. The IAM policy controls what those workflows can do, such as publishing ECR images or deploying to ECS or S3.

See [trust policy and role](main.tf), [OIDC inputs](variables.tf), and [role outputs](outputs.tf).
