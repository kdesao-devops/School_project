locals {
  splitted_value = "${split("-", terraform.workspace)}"
  environment    = "${local.splitted_value[0]}"
  application    = "${local.splitted_value[1]}"
  name_prefix    = "${local.environment}-${local.application}"
  region         = "${join("-",list("${local.splitted_value[2]}", "${local.splitted_value[3]}", "${local.splitted_value[4]}"))}"
  workspaces     = "${merge(local.testing, local.production)}"
  workspace      = "${merge(local.workspaces[local.environment])}"

  # Route 53
  site_domain    = "${local.workspace["site_domain"]}"
  site_subdomain = "${local.workspace["site_subdomain"]}"

  tags = {
    environment = "${local.environment}"
    application = "${local.application}"
  }
}

##############
##   Data   ##
##############

data "aws_route53_zone" "zone" {
  provider = "aws.root"

  name = "${local.site_domain}"
}

############
## Module ##
############

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v1.72.0"

  name = "advoko"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = "${local.tags}"
}

### Récuperation de la dernière version du site

data "aws_ami" "site_ami" {
  owners     = ["self"]
  name_regex = "advoko-site"

  filter {
    name   = "tag:Env"
    values = ["${local.environment}"]
  }

  filter {
    name   = "tag:Status"
    values = ["DeployReady"]
  }

  most_recent = true
}

module "site" {
  source = "github.com/nextkdesao/module-advoko-ec2"

  environment = "${local.environment}"
  application = "${local.application}"
  region      = "${local.region}"

  vpc_id            = "${module.vpc.vpc_id}"
  asg_subnets_ids   = "${module.vpc.private_subnets}"
  lb_subnets_ids    = "${module.vpc.public_subnets}"
  asg_min_size      = "1"
  asg_max_size      = "1"
  ec2_ami           = "${data.aws_ami.site_ami.image_id}"
  ec2_instance_type = "t2.micro"

  zone_id        = "${data.aws_route53_zone.zone.zone_id}"
  site_domain    = "${local.site_domain}"
  site_subdomain = "${local.site_subdomain}"

  tags = "${local.tags}"
}
