# DynamoDB

Creates a DynamoDB table for TikTo tasks and events. The fixed application schema uses `scope` as the partition key and `id` as the sort key. The table uses on-demand billing.

Dev and Prod pass their own table names and protection settings. Prod enables point-in-time recovery and deletion protection. The table name configures the Backend, and its ARN scopes the Backend's IAM permissions.

See [table definition](main.tf), [protection settings](variables.tf), and [table outputs](outputs.tf).
