# ECR

Creates an ECR repository and lifecycle policy for each repository name supplied by the caller. Repositories use immutable tags, scan images on push, and enable AES-256 encryption.

Shared supplies `tikto/backend` and `tikto/notification`. The lifecycle policy expires untagged images after seven days. Its count rule applies to images with tags matching both the `sha-` and `v` prefixes.

See [repositories and lifecycle policy](main.tf), [repository inputs](variables.tf), and [registry URLs and ARNs](outputs.tf).
