terraform {
  required_version = ">= 1.3.0"
  cloud {
    organization = "cklewar"

    workspaces {
      name = "aws-ec2-module"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.32.0"
    }

    local = ">= 2.2.3"
    null  = ">= 3.1.1"
  }
}