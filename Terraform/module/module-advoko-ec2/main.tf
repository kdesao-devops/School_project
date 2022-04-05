locals {
  environment = "${var.environment}"
  application = "${var.application}"
  name_prefix = "${local.environment}-${local.application}"
  region      = "${var.region}"

  vpc_id          = "${var.vpc_id}"
  lb_subnets_ids  = "${var.lb_subnets_ids}"
  asg_subnets_ids = "${var.asg_subnets_ids}"

  asg_min_size = "${var.asg_min_size}"
  asg_max_size = "${var.asg_max_size}"

  ec2_ami           = "${var.ec2_ami}"
  ec2_instance_type = "${var.ec2_instance_type}"

  bastion_sg = "${aws_security_group.this_loadbalancer.id}"

  # Route 53
  zone_id        = "${var.zone_id}"
  site_domain    = "${var.site_domain}"
  site_subdomain = "${var.site_subdomain}"
  site_url       = "${local.site_subdomain}.${local.site_domain}"

  tags = "${var.tags}"
}

################
##  Route 53  ##
################

resource "aws_route53_record" "site_front" {
  provider = "aws.root"

  zone_id = "${local.zone_id}"
  name    = "${local.site_url}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${aws_cloudfront_distribution.this_site.domain_name}"]
}

#####################
## Cloudfront Site ##
#####################

# Bucket s3 for logs

resource "aws_s3_bucket" "this_logs" {
  bucket        = "${local.name_prefix}-logs-site"
  acl           = "private"
  force_destroy = true
}

######### Distribution cloudfront pour le site ########

resource "aws_cloudfront_distribution" "this_site" {
  origin {
    domain_name = "${aws_alb.this_site.dns_name}"
    origin_id   = "origin-${local.name_prefix}-site"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_read_timeout    = 60
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "${local.name_prefix}-admin-api"
  wait_for_deployment = "false"

  logging_config {
    include_cookies = false
    bucket          = "${aws_s3_bucket.this_logs.bucket_domain_name}"
    prefix          = "${local.site_url}"
  }

  aliases = ["${local.site_url}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "${aws_acm_certificate_validation.this_site.certificate_arn}"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  ########### Lower cahcing time for 5xx ##################
  custom_error_response {
    error_code            = 500
    error_caching_min_ttl = 2
  }

  custom_error_response {
    error_code            = 501
    error_caching_min_ttl = 2
  }

  custom_error_response {
    error_code            = 502
    error_caching_min_ttl = 2
  }

  custom_error_response {
    error_code            = 503
    error_caching_min_ttl = 2
  }

  custom_error_response {
    error_code            = 504
    error_caching_min_ttl = 2
  }

  ###########  Configuration par defaut ##################

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-${local.name_prefix}-site"
    compress         = true

    forwarded_values {
      query_string = false
      headers      = ["Host", "CloudFront-Forwarded-Proto", "Referer"]

      cookies {
        forward           = "whitelist"
        whitelisted_names = ["token", "refresh-token"]
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  tags = "${merge(local.tags,map(
      "Description" , "site"
    ))}"
}

###################
## Load balancer ##
###################

resource "aws_alb" "this_site" {
  name            = "${local.name_prefix}-site"
  security_groups = ["${aws_security_group.this_loadbalancer.id}"]
  subnets         = ["${local.lb_subnets_ids}"]

  tags = "${local.tags}"
}

######## Load balancer security group #############

resource "aws_security_group" "this_loadbalancer" {
  name        = "${local.name_prefix}-loadbalancer-site"
  vpc_id      = "${local.vpc_id}"
  description = "loadbalancer security group for ${local.name_prefix}"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(local.tags, map("Name", "advoko-site"))}"
}

resource "aws_security_group_rule" "lb_cloudfront_ingress" {
  type        = "ingress"
  from_port   = "80"
  to_port     = "80"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.this_loadbalancer.id}"
}

resource "aws_security_group_rule" "lb_egress" {
  type        = "egress"
  from_port   = "0"
  to_port     = "0"
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.this_loadbalancer.id}"
}

######## Target group ###########

resource "aws_alb_target_group" "this_site" {
  name                 = "${local.name_prefix}-tg-site"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = "${local.vpc_id}"
  deregistration_delay = 30

  health_check {
    port = 80
    path = "/main.html"
  }
}

###### Listener pour le target group api sur l'alb #######
resource "aws_alb_listener" "advoko_http" {
  load_balancer_arn = "${aws_alb.this_site.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.this_site.id}"
    type             = "forward"
  }
}

###############
##### ASG #####
###############

resource "aws_autoscaling_group" "this_site" {
  lifecycle {
    create_before_destroy = true
  }

  name                = "${aws_launch_configuration.this_site.id}-site"
  vpc_zone_identifier = ["${local.asg_subnets_ids}"]
  min_size            = "${local.asg_min_size}"
  max_size            = "${local.asg_max_size}"

  health_check_grace_period = "100"
  termination_policies      = ["OldestLaunchConfiguration"]
  health_check_type         = "ELB"
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

  ##### Required for immutable deployments without outage #####

  # This will add a link with the target group for terraform
  target_group_arns    = ["${aws_alb_target_group.this_site.arn}"]
  launch_configuration = "${aws_launch_configuration.this_site.id}"

  # This will ask terraform to wait for a minimum of healthy instance in the target group before
  # considering the ressource creation finished

  min_elb_capacity = "${local.asg_min_size}"
  tags = [
    {
      key                 = "Name"
      value               = "${local.name_prefix}-site"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "${local.environment}"
      propagate_at_launch = true
    },
    {
      key                 = "Application"
      value               = "${local.application}"
      propagate_at_launch = true
    },
  ]
}

############# Autoscaling Policy with target cpu tracking #############
resource "aws_autoscaling_policy" "this_site" {
  name                   = "Upscaling policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = "${aws_autoscaling_group.this_site.name}"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    ### The cpu target value to maintain
    target_value = "70.0"
  }
}

###################
## Launch config ##
###################

resource "aws_launch_configuration" "this_site" {
  name_prefix                 = "${local.name_prefix}-site"
  image_id                    = "${local.ec2_ami}"
  instance_type               = "${local.ec2_instance_type}"
  associate_public_ip_address = false
  security_groups             = ["${aws_security_group.this_site.id}"]

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
  }

  lifecycle {
    create_before_destroy = true
  }
}

################ Security group EC2 admin #############
resource "aws_security_group" "this_site" {
  name        = "${local.name_prefix}-ec2-site"
  description = "Security group for ${local.name_prefix} site"
  vpc_id      = "${local.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${local.tags}"
}

resource "aws_security_group_rule" "lb_http_ingress" {
  type                     = "ingress"
  from_port                = "80"
  to_port                  = "80"
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.this_loadbalancer.id}"

  security_group_id = "${aws_security_group.this_site.id}"
}

resource "aws_security_group_rule" "ssh_from_vpc" {
  type                     = "ingress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  source_security_group_id = "${local.bastion_sg}"

  security_group_id = "${aws_security_group.this_site.id}"
}

resource "aws_security_group_rule" "site_ec2_egress" {
  type        = "egress"
  from_port   = "0"
  to_port     = "0"
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.this_site.id}"
}

# On mets a jour la clé priver du site dans SSM
data "aws_ssm_parameter" "site_private_key" {
  name = "/${local.environment}/${local.application}/site_private_key_awaiting"
}

resource "aws_ssm_parameter" "ssh_private_key" {
  name        = "/${var.environment}/${var.application}/site_private_key"
  description = "${aws_launch_configuration.this_site.image_id}"
  type        = "SecureString"
  value       = "${data.aws_ssm_parameter.site_private_key.value}"
  overwrite   = true

  tags = "${local.tags}"
}

### Création d'un certificat pour le site

resource "aws_acm_certificate" "this_site" {
  provider          = "aws.virginia"
  domain_name       = "${local.site_url}"
  validation_method = "DNS"

  tags = {
    Name        = "${local.site_url}"
    Environment = "${local.environment}"
    Application = "${local.application}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  provider = "aws.root"

  name    = "${lookup(aws_acm_certificate.this_site.domain_validation_options[count.index], "resource_record_name")}"
  type    = "${lookup(aws_acm_certificate.this_site.domain_validation_options[count.index], "resource_record_type")}"
  zone_id = "${local.zone_id}"
  records = ["${lookup(aws_acm_certificate.this_site.domain_validation_options[count.index], "resource_record_value")}"]
  ttl     = "60"
}

resource "aws_acm_certificate_validation" "this_site" {
  provider        = "aws.virginia"
  certificate_arn = "${aws_acm_certificate.this_site.arn}"

  validation_record_fqdns = [
    "${aws_route53_record.validation.*.fqdn}",
  ]
}
