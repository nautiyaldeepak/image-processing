output "origin_bucket_name" {
  description = "Origin bucket Name"
  value       = aws_s3_bucket.origin_bucket.bucket
}

output "transform_bucket_name" {
  description = "Transform bucket Name"
  value       = aws_s3_bucket.transform_bucket.bucket
}