resource "aws_dynamodb_table" "this" {
  name                        = var.name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "scope"
  range_key                   = "id"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "scope"
    type = "S"
  }

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name      = var.name
    ManagedBy = "Terraform"
    Module    = "dynamodb"
  })
}
