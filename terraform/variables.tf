variable "domain_name" {
  description = "[Deprecated - use `route53_zone_arns`] Domain name of the Route53 hosted zone to use with External DNS."
  type        = string
  default     = "thecaptainhub.com"
}
variable "private_zone" {
  description = "[Deprecated - use `route53_zone_arns`] Determines if referenced Route53 hosted zone is private."
  type        = bool
  default     = false
}

