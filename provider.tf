# ==============================================================================
# BLOCK 1: TERRAFORM CORE INITIALIZATION
# ==============================================================================
# This block pins the version rules so updates don't break your code.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Restricts updates to safe, minor revisions within v5.x
    }
  }
}

# ==============================================================================
# BLOCK 2: AWS PROVIDER CONFIGURATION
# ==============================================================================
# This specifies the deployment target region and enforces global tracking tags.
provider "aws" {
  region = "us-east-1" # Primary AWS Data Center Hub
  
  # Global Tagging Governance: Every resource created inherits these tags automatically.
  default_tags {
    tags = {
      Project     = "Armadin-Lab"
      Domain      = "p46.ai"
      Environment = "Production-Testbed"
      ManagedBy   = "Terraform"
    }
  }
}