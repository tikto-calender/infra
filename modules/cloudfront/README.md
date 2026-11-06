# CloudFront

Serves the frontend from a private S3 bucket through CloudFront Origin Access Control. A separate behavior forwards `/api/*` to the configured API origin with caching disabled.

Dev and Prod supply their own bucket and Public ALB. The module also accepts an optional custom domain, ACM certificate, and Route 53 zone.

See [S3, CloudFront, and routing](main.tf), [origin and domain inputs](variables.tf), and [deployment outputs](outputs.tf).
