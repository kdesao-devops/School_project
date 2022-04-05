######################
## Common Variables ##
######################

variable "environment" {
  description = "Nom de l environment"
  type        = "string"
}

variable "application" {
  description = "Nom de l application"
  type        = "string"
}

variable "region" {
  description = "Région dans laquelle créer les ressources"
  type        = "string"
}

variable "tags" {
  description = "List de tags pour les ressources crées par le module"
  type        = "map"
}

######################
## Module Variables ##
######################

### Route 53 ###
variable "zone_id" {
  description = "ID de la zone d'hébergement ou enregistrer l'adresse DNS"
}

variable "site_domain" {
  description = "Le nom de domaine dans lequel le site sera enregistré"
}

variable "site_subdomain" {
  description = "Le sous domaine dans lequel le site sera enregistré"
}

### Réseau ###

variable "vpc_id" {
  description = "ID du VPC dans lequel déploier le site"
}

variable "lb_subnets_ids" {
  description = "Sous réseaux dans lequel sera créée le load balancer"
  type        = "list"
}

variable "asg_subnets_ids" {
  description = "Sous réseaux dans lequel sera créée le auto scaling group"
  type        = "list"
}

### Auto scaling group ###

variable "asg_min_size" {
  description = "Nombre minimal de serveur dans le auto scaling group"
}

variable "asg_max_size" {
  description = "Nombre maximal de serveur dans le auto scaling group"
}

variable "ec2_ami" {
  description = "AMI a déployer pour créer le serveur du site"
}

variable "ec2_instance_type" {
  description = "Type d'instance a déployer pour le site"
}
