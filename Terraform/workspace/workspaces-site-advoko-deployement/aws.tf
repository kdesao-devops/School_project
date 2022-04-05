provider "aws" {
  version = "<= 2.59.0"

  assume_role {
    role_arn = "${local.workspace["role_arn"]}"
  }

  region = "${local.region}"
}
