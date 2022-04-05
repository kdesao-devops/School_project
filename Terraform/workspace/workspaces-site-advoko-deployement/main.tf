locals {
  splitted_value = "${split("-", terraform.workspace)}"
  environment    = "${local.splitted_value[0]}"
  application    = "${local.splitted_value[1]}"
  name_prefix    = "${local.environment}-${local.application}"
  region         = "${join("-",list("${local.splitted_value[2]}", "${local.splitted_value[3]}", "${local.splitted_value[4]}"))}"

  workspaces = "${merge(local.testing, local.production)}"
  workspace  = "${merge(local.workspaces[local.environment])}"

  terraform_github_repository = "https://github.com/nextkdesao/Projet_annuel_workspaces"
  docker_terraform_account_id = "092537349357"
  docker_terraform_name       = "terraform-builder"
  build_image                 = "${local.docker_terraform_account_id}.dkr.ecr.eu-west-1.amazonaws.com/packer-builder:latest"

  github_user             = "nextkdesao"
  terraform_github_branch = "master"
  terraform_version       = "0.11.14"

  organization               = "nextkdesao"
  pipeline_source_repository = "Projet_annuel_packer"
  pipeline_source_branch     = "master"

  packer_ami_instance_type = "t2.micro"

  tags = {
    environment = "${local.environment}"
    application = "${local.application}"
  }

  # Variable d'environnemment des deux codebuilds terraform
  environment_variables = [
    {
      "name"  = "terraform_github_repository"
      "value" = "${local.terraform_github_repository}"
    },
    {
      "name"  = "GITHUB_TOKEN"
      "value" = "github_token"
      "type"  = "PARAMETER_STORE"
    },
    {
      "name"  = "GITHUB_USER"
      "value" = "${local.github_user}"
    },
    {
      "name"  = "terraform_github_branch"
      "value" = "${local.terraform_github_branch}"
    },
    {
      "name"  = "AWS_ACCESS_KEY_ID"
      "value" = "codebuild_aws_key_id"
      "type"  = "PARAMETER_STORE"
    },
    {
      "name"  = "AWS_SECRET_ACCESS_KEY"
      "value" = "codebuild_aws_secret_key"
      "type"  = "PARAMETER_STORE"
    },
    {
      "name"  = "ENVIRONMENT"
      "value" = "${local.environment}"
    },
    {
      "name"  = "APPLICATION"
      "value" = "${local.application}"
    },
    {
      "name"  = "REGION"
      "value" = "${local.region}"
    },
    {
      "name"  = "TERRRAFORM_VERSION"
      "value" = "${local.terraform_version}"
    },
  ]
}

#########################
######## DATA ###########
#########################

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "github_token" {
  name = "github_token"
}

#########################
####### IAM roles #######
#########################

# Role utilisé par le pipeline packer
resource "aws_iam_role" "this_codepipeline" {
  name                  = "${local.name_prefix}-codepipeline-site"
  force_detach_policies = true

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Role utilisé par le codebuild packer / ansible
resource "aws_iam_role" "this_codebuild_packer" {
  name                  = "${local.name_prefix}-codebuild-packer-site"
  force_detach_policies = true

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Role utilisé par l'ec2 lancée par packer sur lequel ansible est écecuté
resource "aws_iam_role" "this_packer_ec2" {
  name                  = "${local.name_prefix}-site-packer-ec2"
  force_detach_policies = true

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Création d'un profile pour l'instance ec2
resource "aws_iam_instance_profile" "this_packer_ec2" {
  name = "${local.name_prefix}-site-ec2"
  role = "${aws_iam_role.this_packer_ec2.name}"
}

# Role utilisé par les deux codebuilds terraform
resource "aws_iam_role" "this_codebuild_terraform" {
  name                  = "${local.name_prefix}-codebuild-terraform-site"
  force_detach_policies = true

  assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Action": "sts:AssumeRole",
			"Principal": {
				"Service": "codebuild.amazonaws.com"
			},
			"Effect": "Allow",
			"Sid": ""
		}
	]
}
EOF
}

# Role utilisé par le cloudwatch trigger
resource "aws_iam_role" "this_cloudwatch_trigger" {
  name                  = "${local.name_prefix}-pipeline-site-cloudwatch-trigger"
  force_detach_policies = true

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#########################
##### IAM policies ######
#########################

# Policy du codepipeline
resource "aws_iam_role_policy" "this_codepipeline" {
  name = "${local.name_prefix}-codepipeline-site"
  role = "${aws_iam_role.this_codepipeline.id}"

  policy = "${data.template_file.this_codepipeline.rendered}"
}

# Policy pour le codebuild qui gère packer
resource "aws_iam_role_policy" "this_codebuild_packer" {
  name = "${local.name_prefix}-codebuild-packer-site"
  role = "${aws_iam_role.this_codebuild_packer.id}"

  policy = "${data.template_file.this_codebuild_packer.rendered}"
}

# Policy L'ec2 lancée par packer
resource "aws_iam_role_policy" "this_packer_ec2" {
  name = "${local.name_prefix}-codebuild-packer-ec2-site"
  role = "${aws_iam_role.this_packer_ec2.id}"

  policy = "${data.template_file.this_packer_ec2.rendered}"
}

# Policy des deux codebuilds terraform
resource "aws_iam_role_policy" "this_codebuild_terraform" {
  name = "${local.name_prefix}-codebuild-terraform-site"
  role = "${aws_iam_role.this_codebuild_terraform.name}"

  policy = "${data.template_file.this_codebuild_terraform.rendered}"
}

# Policy pour les droits packer dans le codebuild
resource "aws_iam_role_policy" "this_packer" {
  name   = "${local.name_prefix}-packer"
  role   = "${aws_iam_role.this_codebuild_packer.id}"
  policy = "${file("${path.module}/policies/packer.json")}"
}

# Ajout d'un droit de lancement du pipeline au role cloudwatch trigger
resource "aws_iam_role_policy" "cloudwatch_trigger" {
  name = "${local.name_prefix}-pipeline-site-cloudwatch-trigger"
  role = "${aws_iam_role.this_cloudwatch_trigger.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_codepipeline.this.arn}"
      ],
      "Action": [
        "codepipeline:StartPipelineExecution"
      ]
    }
  ]
}
POLICY
}

#########################
##### Data Policies #####
#########################

# Récupération et templating de la policy de codepipeline
data "template_file" "this_codepipeline" {
  template = "${file("${path.module}/policies/codepipeline.json")}"

  vars {
    name_prefix             = "${local.name_prefix}"
    region                  = "${local.region}"
    codepipeline_bucket_arn = "${aws_s3_bucket.this_codepipeline.arn}"
    account_id              = "${data.aws_caller_identity.current.account_id}"
  }
}

# Récupération et templating de la policy du codebuild_packer
data "template_file" "this_codebuild_packer" {
  template = "${file("${path.module}/policies/codebuild_packer.json")}"

  vars {
    account_id              = "${data.aws_caller_identity.current.account_id}"
    docker_account_id       = "${local.docker_terraform_account_id}"
    name_prefix             = "${local.name_prefix}"
    region                  = "${local.region}"
    codepipeline_bucket_arn = "${aws_s3_bucket.this_codepipeline.arn}"
  }
}

# Récupération et templating de la policy de l'ec2
data "template_file" "this_packer_ec2" {
  template = "${file("${path.module}/policies/ec2.json")}"

  vars {
    account_id  = "${data.aws_caller_identity.current.account_id}"
    region      = "${local.region}"
    application = "${local.application}"
    environment = "${local.environment}"
  }
}

# Récupération et templating de la policy du codebuild terraform
data "template_file" "this_codebuild_terraform" {
  template = "${file("${path.module}/policies/codebuild_terraform.json")}"

  vars {
    account_id                  = "${data.aws_caller_identity.current.account_id}"
    region                      = "${local.region}"
    name_prefix                 = "${local.name_prefix}"
    codepipeline_bucket_arn     = "${aws_s3_bucket.this_codepipeline.arn}"
    docker_terraform_account_id = "${local.docker_terraform_account_id}"
    docker_terraform_name       = "${local.docker_terraform_name}"
  }
}

###############
## CodeBuild ##
###############

# Création du CodeBuild packer
resource "aws_codebuild_project" "this_packer" {
  name         = "${local.name_prefix}-packer-site"
  service_role = "${aws_iam_role.this_codebuild_packer.arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "${local.build_image}"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable {
      "name"  = "environment"
      "value" = "${local.environment}"
    }

    environment_variable {
      "name"  = "application"
      "value" = "${local.application}"
    }

    environment_variable {
      "name"  = "instance_type"
      "value" = "${local.packer_ami_instance_type}"
    }

    environment_variable {
      "name"  = "region"
      "value" = "${local.region}"
    }
  }

  source {
    buildspec = ""
    type      = "GITHUB"
    location  = "${local.terraform_github_repository}"
  }

  tags = "${merge(local.tags,map("Description","Packer codebuild for ${local.name_prefix}"))}"
}

# Création du codebuild qui effectue un terraform plan sur l'environnement
resource "aws_codebuild_project" "this_plan" {
  name         = "${local.name_prefix}-tf-plan-site"
  description  = "CodeBuild terraform plan for the site part of ${local.name_prefix}"
  service_role = "${aws_iam_role.this_codebuild_terraform.arn}"

  artifacts {
    type     = "NO_ARTIFACTS"
    location = ""
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "${local.docker_terraform_account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.docker_terraform_name}:latest"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable = "${local.environment_variables}"
  }

  source {
    # Required
    type = "NO_SOURCE"

    buildspec = <<BUILDSPEC
    version: 0.2
    phases:
      install:
        commands:
          - export PATH=/root/.local/bin:$PATH
          - echo "configuration des credentials aws"
          - mkdir -p /root/.aws/
          - echo "Adding master user credentials into aws config file:"
          - echo "[default]" >> /root/.aws/config
          - echo "aws_access_key_id=$${AWS_ACCESS_KEY_ID}" >> /root/.aws/config
          - echo "aws_secret_access_key=$${AWS_SECRET_ACCESS_KEY}" >> /root/.aws/config
          - echo "region=${local.region}" >> /root/.aws/config
          - echo "[profile child]" >> /root/.aws/config
          - echo "role_arn = arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-full-access" >> /root/.aws/config
          - echo "source_profile = default" >> /root/.aws/config
          - echo "region=${local.region}" >> /root/.aws/config
          - git config --global credential.helper store
          - echo "https://$${GITHUB_USER}:$${GITHUB_TOKEN}@github.com" > ~/.git-credentials
          - git clone -b "$${terraform_github_branch}" "$${terraform_github_repository}" terraform_dir
          - cd terraform_dir
          - terraform init
          - echo "commande terraform init terminée"
      pre_build:
        commands:
          - ami_id_path=`find $CODEBUILD_SRC_DIR_manifest -name "manifest.json"`
          - AMI_ID=`cat $$ami_id_path | jq -r '.builds[0].artifact_id' |  cut -d':' -f2`
          - |
            if [ -n "$AMI_ID" ];
            then
              echo "AMI found : $AMI_ID"
              aws ec2 --profile child create-tags --resources $AMI_ID --tags Key=Status,Value=DeployReady
              echo "$AMI_ID" > $$CODEBUILD_SRC_DIR/ami_id
            else
              echo "No AMI_ID found"
              exit 1
            fi
      build:
        commands:
          - terraform workspace select "$${ENVIRONMENT}-$${APPLICATION}-$${REGION}"

          - terraform plan --target=module.site -out=$$CODEBUILD_SRC_DIR/plan_result

        finally:
         - ami_id_path=`find $CODEBUILD_SRC_DIR_manifest -name "manifest.json"`
         - AMI_ID=`cat $$CODEBUILD_SRC_DIR/ami_id`
         - |
          if [[ -n "$AMI_ID" || "$AMI_ID" == "None" ]];
          then
            echo "AMI found : $AMI_ID"
            aws ec2  --profile child create-tags --resources $AMI_ID --tags Key=Status,Value=PendingValidation
          else
            echo "No AMI_ID found"
            exit 1
          fi
    artifacts:
      secondary-artifacts:
        build_plan:
          files:
            - $$CODEBUILD_SRC_DIR/plan_result
          name: plan-result
        ami_id:
          files:
            - $$CODEBUILD_SRC_DIR/ami_id
          name: ami_id

BUILDSPEC
  }
}

# Création du codebuild qui effectue un terraform apply sur l'environnement
resource "aws_codebuild_project" "this_apply" {
  name         = "${local.name_prefix}-tf-apply-site"
  description  = "CodeBuild terraform apply for the site part of ${local.name_prefix}"
  service_role = "${aws_iam_role.this_codebuild_terraform.arn}"

  source {
    # Required
    type = "NO_SOURCE"

    buildspec = <<BUILDSPEC
    version: 0.2
    phases:
      install:
        commands:
          - echo "configuration des credentials aws"
          - mkdir -p /root/.aws/
          - echo "Adding master user credentials into aws config file:"
          - echo "[default]" >> /root/.aws/config
          - echo "aws_access_key_id=$${AWS_ACCESS_KEY_ID}" >> /root/.aws/config
          - echo "aws_secret_access_key=$${AWS_SECRET_ACCESS_KEY}" >> /root/.aws/config
          - echo "region=${local.region}" >> /root/.aws/config
          - echo "[profile child]" >> /root/.aws/config
          - echo "role_arn = arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-full-access" >> /root/.aws/config
          - echo "source_profile = default" >> /root/.aws/config
          - echo "region=${local.region}" >> /root/.aws/config
          - git config --global credential.helper store
          - echo "https://$${GITHUB_USER}:$${GITHUB_TOKEN}@github.com" > ~/.git-credentials
          - git clone -b "$${terraform_github_branch}" "$${terraform_github_repository}" terraform_dir
          - plan_result_path=`find . -type f -name plan_result`
          - mv $$plan_result_path terraform_dir
          - cd terraform_dir
          - terraform init
          - echo "commande terraform init terminée"
      pre_build:
        commands:
          - ami_id_path=`find $CODEBUILD_SRC_DIR_ami_id -name ami_id`
          - AMI_ID=`cat $$ami_id_path`
          - |
            if [[ -n "$AMI_ID" || "$AMI_ID" != "None" ]];
            then
              echo "AMI found : $AMI_ID"
              aws ec2 --profile child create-tags --resources $AMI_ID --tags Key=Status,Value=DeployReady
            else
              echo "No AMI_ID found"
              exit 1
            fi
      build:
        commands:
        - terraform workspace select "$${ENVIRONMENT}-$${APPLICATION}-$${REGION}"

        - terraform apply -auto-approve -no-color
      post_build:
        commands:
        - ami_id_path=`find $CODEBUILD_SRC_DIR_ami_id -name ami_id`
        - AMI_ID=`cat $$ami_id_path`
        - |
          if [[ -n "$AMI_ID" || "$AMI_ID" == "None" ]];
          then
            echo "AMI found : $AMI_ID"
            aws ec2 --profile child create-tags --resources $AMI_ID --tags Key=Deploy_Date,Value="$(date)"
          else
            echo "No AMI_ID found"
            exit 1
          fi

BUILDSPEC
  }

  cache {
    type = "NO_CACHE"
  }

  artifacts {
    type     = "NO_ARTIFACTS"
    location = ""
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "${local.docker_terraform_account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.docker_terraform_name}:latest"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable = "${local.environment_variables}"
  }

  tags = "${local.tags}"
}

##############################################
##### Création du s3 bucket codepipeline #####
##############################################

resource "aws_s3_bucket" "this_codepipeline" {
  bucket        = "${local.name_prefix}-codepipeline-packer-site"
  acl           = "private"
  force_destroy = true
}

#######################################
##### CodePipeline with approval ######
#######################################

resource "aws_codepipeline" "this" {
  name     = "${local.name_prefix}-terraform-site"
  role_arn = "${aws_iam_role.this_codepipeline.arn}"

  artifact_store {
    location = "${aws_s3_bucket.this_codepipeline.bucket}"
    type     = "S3"
  }

  stage {
    name = "1-Source"

    action {
      name             = "Github"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["github_output"]

      configuration = {
        OAuthToken           = "${data.aws_ssm_parameter.github_token.value}"
        Owner                = "${local.organization}"
        Repo                 = "${local.pipeline_source_repository}"
        Branch               = "${local.pipeline_source_branch}"
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "2-Build-AMI"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["github_output"]
      output_artifacts = ["manifest"]
      version          = "1"

      configuration = {
        ProjectName   = "${aws_codebuild_project.this_packer.name}"
        PrimarySource = "source_output"
      }
    }
  }

  stage {
    name = "3-Terraform-Plan"

    action {
      name             = "terraform-plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["github_output", "manifest"]
      output_artifacts = ["build_plan", "ami_id"]
      version          = "1"

      configuration = {
        ProjectName   = "${aws_codebuild_project.this_plan.id}"
        PrimarySource = "github_output"
      }
    }
  }

  stage {
    name = "4-Manual-Approval"

    action {
      name     = "slack-approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "Final-Terraform-Apply"

    action {
      name            = "terraform-apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["build_plan", "ami_id"]
      version         = "1"

      configuration = {
        ProjectName   = "${aws_codebuild_project.this_apply.id}"
        PrimarySource = "build_plan"
      }
    }
  }
}
