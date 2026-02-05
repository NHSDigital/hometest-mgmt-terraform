################################################################################
# CloudFront SPA Module
# CloudFront distribution for SPA with S3 origin and security best practices
################################################################################

locals {
  distribution_name = "${var.project_name}-${var.environment}-spa"
  s3_origin_id      = "S3-${var.project_name}-${var.environment}-spa"
  api_origin_id     = "API-${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Name         = local.distribution_name
      Service      = "cloudfront"
      ManagedBy    = "terraform"
      Module       = "cloudfront-spa"
      ResourceType = "distribution"
    }
  )
}

################################################################################
# S3 Bucket for SPA Static Assets
################################################################################

resource "aws_s3_bucket" "spa" {
  bucket = "${var.project_name}-${var.environment}-spa-${var.aws_account_id}"

  tags = merge(local.common_tags, {
    ResourceType = "s3-bucket"
    Purpose      = "spa-static-assets"
  })
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "spa" {
  bucket = aws_s3_bucket.spa.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "spa" {
  bucket = aws_s3_bucket.spa.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "spa" {
  bucket = aws_s3_bucket.spa.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.s3_kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.s3_kms_key_arn
    }
    bucket_key_enabled = var.s3_kms_key_arn != null
  }
}

# Lifecycle rules for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "spa" {
  bucket = aws_s3_bucket.spa.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.s3_noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 bucket policy for CloudFront OAC
resource "aws_s3_bucket_policy" "spa" {
  bucket = aws_s3_bucket.spa.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.spa.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.spa.arn
          }
        }
      }
    ]
  })
}

################################################################################
# CloudFront Origin Access Control (OAC)
################################################################################

resource "aws_cloudfront_origin_access_control" "spa" {
  name                              = local.distribution_name
  description                       = "OAC for ${local.distribution_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

################################################################################
# CloudFront Response Headers Policy
################################################################################

resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${local.distribution_name}-security-headers"
  comment = "Security headers for ${local.distribution_name}"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_security_policy {
      content_security_policy = var.content_security_policy
      override                = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = var.permissions_policy
      override = true
    }
  }
}

################################################################################
# CloudFront Cache Policy for SPA
################################################################################

resource "aws_cloudfront_cache_policy" "spa" {
  name        = "${local.distribution_name}-cache-policy"
  comment     = "Cache policy for SPA static assets"
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

################################################################################
# CloudFront Distribution
################################################################################

resource "aws_cloudfront_distribution" "spa" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${local.distribution_name}"
  default_root_object = "index.html"
  price_class         = var.price_class
  http_version        = "http2and3"
  aliases             = var.custom_domain_names

  # S3 Origin for static assets
  origin {
    domain_name              = aws_s3_bucket.spa.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.spa.id
  }

  # API Gateway Origin (optional)
  dynamic "origin" {
    for_each = var.api_gateway_domain_name != null ? [1] : []
    content {
      domain_name = var.api_gateway_domain_name
      origin_id   = local.api_origin_id
      origin_path = var.api_gateway_origin_path

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default behavior for SPA
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    cache_policy_id            = aws_cloudfront_cache_policy.spa.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Function associations for SPA routing
    dynamic "function_association" {
      for_each = var.enable_spa_routing ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.spa_routing[0].arn
      }
    }
  }

  # API path behavior (optional)
  dynamic "ordered_cache_behavior" {
    for_each = var.api_gateway_domain_name != null ? [1] : []
    content {
      path_pattern     = "/api/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = local.api_origin_id

      # No caching for API calls
      cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
      origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader

      viewer_protocol_policy = "redirect-to-https"
      compress               = true
    }
  }

  # SPA routing for client-side routes
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # Geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL/TLS Configuration
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != null ? "TLSv1.2_2021" : null
  }

  # WAF Association
  web_acl_id = var.waf_web_acl_arn

  # Logging
  dynamic "logging_config" {
    for_each = var.enable_access_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = var.logging_bucket_domain_name
      prefix          = "cloudfront/${local.distribution_name}/"
    }
  }

  tags = local.common_tags
}

################################################################################
# CloudFront Function for SPA Routing
################################################################################

resource "aws_cloudfront_function" "spa_routing" {
  count = var.enable_spa_routing ? 1 : 0

  name    = "${replace(local.distribution_name, "-", "_")}_spa_routing"
  runtime = "cloudfront-js-2.0"
  comment = "SPA routing function for ${local.distribution_name}"
  publish = true

  code = <<-EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Check if the request is for a file (has extension)
    if (uri.includes('.')) {
        return request;
    }

    // Check if path starts with /api/ - don't rewrite API calls
    if (uri.startsWith('/api/')) {
        return request;
    }

    // For all other requests, serve index.html
    request.uri = '/index.html';
    return request;
}
EOF
}

################################################################################
# Route53 Record (optional)
################################################################################

resource "aws_route53_record" "spa" {
  count = var.route53_zone_id != null && length(var.custom_domain_names) > 0 ? length(var.custom_domain_names) : 0

  zone_id = var.route53_zone_id
  name    = var.custom_domain_names[count.index]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.spa.domain_name
    zone_id                = aws_cloudfront_distribution.spa.hosted_zone_id
    evaluate_target_health = false
  }
}
