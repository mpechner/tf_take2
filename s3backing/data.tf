data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}
data "aws_kms_alias" "dynamodb" {
  name = "alias/aws/dynamodb"
}
