## Module de création d'AMI pour le site advoko

## Introduction

It uses packer to create an EC2 on AWS then it installs the requirements to run the Ansible playbook on the instance.

Finally Ansible install and configure all the packages to run advoko site.

To make the CI all this is run in a docker (from the dockerfile) launch by CodeBuild.

# Usage

Pour utilisé ce module plusieurs conditions doivent etre réunies.

Tout d'abord on doit installer packer:
`brew install packer`

Ensuite on doit configurer des variable d'env (attention les variables access et secret sont les credentials AWS CLI):
```
export "environment"="testing"
export "application"="advoko"
export "region"="eu-west-1"
export "instance_type"="t2.micro"
export "access"="access"
export "secret"="secret"
```

Enfin on peut éxecuter le packer :
`packer build packer_advoko.json`
