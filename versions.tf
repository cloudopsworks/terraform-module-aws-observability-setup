##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.69.0, < 7.0.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.58.0, < 2.0.0"
    }
  }
}
