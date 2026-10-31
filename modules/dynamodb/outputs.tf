output "name" {
  value       = aws_dynamodb_table.this.name
  description = "DynamoDB table name."
}

output "arn" {
  value       = aws_dynamodb_table.this.arn
  description = "DynamoDB table ARN."
}
