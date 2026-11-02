terraform {
  required_version = ">= 1.17.1, < 2.0.0"

  required_providers {
    cpwai = {
      source  = "CheckPointSW/checkpoint-workforce-ai"
      version = "~> 1.0.2"
    }
  }
}

provider "cpwai" {
  client_id  = var.checkpoint_client_id
  access_key = var.checkpoint_access_key
  region     = var.checkpoint_region
}
