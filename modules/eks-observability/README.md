# EKS Observability

Installs the CloudWatch Observability add-on for an EKS cluster. It creates application and performance log groups, a dashboard, and alarms for node CPU, memory, and failures.

The caller supplies the cluster name and can set log retention and SNS alarm actions. Prod retains these log groups for 30 days.

See [add-on, dashboard, and alarms](main.tf), [observability inputs](variables.tf), and [CloudWatch outputs](outputs.tf).
