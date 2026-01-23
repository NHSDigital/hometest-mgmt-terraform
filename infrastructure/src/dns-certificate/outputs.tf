################################################################################
# Outputs - DNS Certificate Module
################################################################################

#------------------------------------------------------------------------------
# Certificate Outputs
#------------------------------------------------------------------------------

output "certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "certificate_domain_name" {
  description = "The domain name of the certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_status" {
  description = "The status of the certificate"
  value       = aws_acm_certificate.main.status
}

output "certificate_validation_emails" {
  description = "Email addresses for certificate validation (if email validation)"
  value       = aws_acm_certificate.main.validation_emails
}

#------------------------------------------------------------------------------
# Route53 Zone Outputs
#------------------------------------------------------------------------------

output "zone_id" {
  description = "The ID of the Route53 hosted zone"
  value       = data.aws_route53_zone.main.zone_id
}

output "zone_name" {
  description = "The name of the Route53 hosted zone"
  value       = data.aws_route53_zone.main.name
}

#------------------------------------------------------------------------------
# FQDN Outputs
#------------------------------------------------------------------------------

output "environment_fqdn" {
  description = "The fully qualified domain name for this environment"
  value       = local.environment_fqdn
}

output "api_endpoint_url" {
  description = "The URL of the API endpoint"
  value       = "https://${local.environment_fqdn}"
}

#------------------------------------------------------------------------------
# Health Check Outputs
#------------------------------------------------------------------------------

output "health_check_id" {
  description = "The ID of the Route53 health check"
  value       = var.create_health_check ? aws_route53_health_check.main[0].id : null
}

#------------------------------------------------------------------------------
# Validation Outputs
#------------------------------------------------------------------------------

output "certificate_validated" {
  description = "Whether the certificate has been validated"
  value       = aws_acm_certificate_validation.main.id != null
}
