provider "aws" {
  version = "<= 2.59.0"

  assume_role {
    role_arn = "${local.workspace["role_arn"]}"
  }

  region = "${local.region}"
}

provider "aws" {
  alias  = "root"
  region = "${local.region}"
}

provider "aws" {
  alias = "virginia"

  assume_role {
    role_arn = "${local.workspace["role_arn"]}"
  }

  region = "us-east-1"
}
