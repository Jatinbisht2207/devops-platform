terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
  backend "s3" {
    # Values come from terraform/bootstrap outputs; override with -backend-config if needed.
    bucket         = "REPLACE-tfstate-bucket"
    key            = "platform/prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}
