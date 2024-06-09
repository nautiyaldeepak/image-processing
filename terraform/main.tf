resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
  numeric = true
}

resource "aws_s3_bucket" "origin_bucket" {
  bucket = "${var.identifier}-image-bucket-origin-${random_string.suffix.result}"
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_s3_bucket" "transform_bucket" {
  bucket = "${var.identifier}-image-bucket-transform-${random_string.suffix.result}"
  tags = {
    Environment = "${var.identifier}"
  }
}

resource "aws_s3_bucket_notification" "origin_bucket_notification" {
  bucket = aws_s3_bucket.origin_bucket.id
  eventbridge = true
}