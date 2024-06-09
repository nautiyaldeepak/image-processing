output "origin_bucket_name" {
  description = "Origin bucket Name | Upload you images in this bucket"
  value       = aws_s3_bucket.origin_bucket.bucket
}

output "transform_bucket_name" {
  description = "Transform bucket Name | Transformed images will be available in this bucket"
  value       = aws_s3_bucket.transform_bucket.bucket
}