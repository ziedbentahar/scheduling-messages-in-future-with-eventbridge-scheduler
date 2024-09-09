terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.52.0"
    }

    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.13.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

