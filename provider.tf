# ==============================================================================
# BLOCK 1: TERRAFORM CORE INITIALIZATION
# ==============================================================================
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" 
    }
  }

  # ----------------------------------------------------------------------------
  # REMOTE STATE STORAGE 
  # ----------------------------------------------------------------------------
  backend "s3" {
    bucket  = "p46-terraform-state-12345" # Your newly created bucket
    key     = "aws-primary/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}