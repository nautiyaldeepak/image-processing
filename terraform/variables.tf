variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "eu-north-1"  # Change to your desired region
}

variable "shared_credentials_file" {
  description = "The path to the shared credentials file."
  type        = string
  default     = "~/.aws/credentials"  # Change to the path of your credentials file
}

variable "aws_profile" {
  description = "The AWS profile to use."
  type        = string
  default     = "default"  # Change to your desired profile
}

variable "identifier" {
  description = "This will be used as a prefix to name resources"
  type        = string
  default     = "testnet"
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the EFS mount targets will be created."
  type        = list(string)
  default     = ["subnet-0a4633ceb176cfd9d", "subnet-0ef89c8644f17f2ed", "subnet-0c756ca41c97718ea"]  # Add default as an empty list
#   default     = ["subnet-0a4", "subnet-0ef", "subnet-0c756c"]
}

variable "vpc_id" {
  description = "The VPC ID where the EFS file system will be created."
  type        = string
  default     = "vpc-0ffa5e60cc0208c47"  # Add default as an empty string
}

variable "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  type        = string
  default     = "172.31.0.0/16"
}