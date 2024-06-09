terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Change to your desired version
    }
  }

  required_version = ">= 1.0.0"
}

provider "aws" {
  region                  = var.aws_region
  shared_credentials_files = [var.shared_credentials_file]
  profile                 = var.aws_profile
}
