terraform {
  backend "s3" {
    bucket         = "backend-terraform-advoko"
    key            = "advoko-site-deployement/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
  }
}
