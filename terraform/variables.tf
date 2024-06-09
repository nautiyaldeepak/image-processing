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