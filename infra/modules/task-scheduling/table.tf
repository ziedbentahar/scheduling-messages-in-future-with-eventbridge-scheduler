resource "aws_dynamodb_table" "table" {
  name         = "${var.application}-${var.environment}-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"


  attribute {
    name = "PK"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}
