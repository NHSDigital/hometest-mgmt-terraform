################################################################################
# Route53 Records for API Custom Domains
################################################################################

resource "aws_route53_record" "api1" {
  count = var.api1_custom_domain_name != null && var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.api1_custom_domain_name
  type    = "A"

  alias {
    name                   = module.api_gateway_1.custom_domain_regional_domain_name
    zone_id                = module.api_gateway_1.custom_domain_regional_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api2" {
  count = var.api2_custom_domain_name != null && var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.api2_custom_domain_name
  type    = "A"

  alias {
    name                   = module.api_gateway_2.custom_domain_regional_domain_name
    zone_id                = module.api_gateway_2.custom_domain_regional_zone_id
    evaluate_target_health = false
  }
}
