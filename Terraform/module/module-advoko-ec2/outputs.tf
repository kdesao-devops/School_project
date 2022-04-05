###################
# site
###################

output "site_front_url" {
  description = "url site"
  value       = "${aws_route53_record.site_front.fqdn}"
}
