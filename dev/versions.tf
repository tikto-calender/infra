terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.54, < 7.0"
    }
  }

  backend "s3" {
    bucket       = "tikto-terraform-state"
    key          = "tikto/dev/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
