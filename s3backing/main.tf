resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = var.backingdb
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  server_side_encryption {
    enabled = true
    kms_key_arn = data.aws_kms_alias.dynamodb.arn
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.backingbucket
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = data.aws_kms_alias.s3.id
      sse_algorithm     = "aws:kms"
    }
  }
}
