# EKS Platform

Creates an EKS cluster, a managed node group, a launch template, core add-ons, and IAM roles. Pod Identity grants the Backend access to DynamoDB and the AWS Load Balancer Controller permission to manage the ALB.

Prod supplies the cluster version, node sizes, subnet placement, and application ServiceAccount. Kubernetes Deployments, Services, and Ingress are defined in the manifest repository. The cluster needs the AWS Load Balancer Controller to reconcile the Ingress.

See [cluster, nodes, and IAM](main.tf), [platform inputs](variables.tf), and [cluster outputs](outputs.tf).
