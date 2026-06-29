# modules/cloudfront/main.tf

# Origin Access Control for S3 origins
resource "aws_cloudfront_origin_access_control" "s3" {
  count = var.s3_origin != null ? 1 : 0

  name                              = "oac-${var.s3_origin.bucket_id}"
  description                       = "OAC for ${var.s3_origin.bucket_id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# FIX: Use aws_caller_identity + locals to break the circular dependency.
# Instead of referencing aws_cloudfront_distribution.this.arn in the bucket
# policy (which doesn't exist yet during planning), we build the ARN from
# known values so Terraform can plan the policy and the distribution together.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  # Construct the distribution ARN without referencing the resource itself.
  # CloudFront ARNs always use "us-east-1" regardless of the deployment region.
  distribution_arn = "arn:${data.aws_partition.current.partition}:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"
}

data "aws_iam_policy_document" "s3_policy" {
  count = var.s3_origin != null ? 1 : 0

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_origin.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "AWS:SourceArn"
      # Wildcard allows any distribution in this account — tighten this to
      # the specific ARN after first apply if you need stricter scoping.
      values = [local.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "origin" {
  count = var.s3_origin != null ? 1 : 0

  bucket = var.s3_origin.bucket_id
  policy = data.aws_iam_policy_document.s3_policy[0].json
}

# The CloudFront distribution
resource "aws_cloudfront_distribution" "this" {
  comment             = var.comment
  enabled             = var.enabled
  default_root_object = var.default_root_object
  aliases             = var.aliases
  price_class         = var.price_class
  web_acl_id          = var.web_acl_id
  http_version        = var.http_version # NEW: e.g. "http2and3"

  # NEW: Access logging (omitted entirely when var.logging is null)
  dynamic "logging_config" {
    for_each = var.logging != null ? [var.logging] : []

    content {
      bucket          = logging_config.value.bucket
      prefix          = logging_config.value.prefix
      include_cookies = logging_config.value.include_cookies
    }
  }

  # S3 origin (if configured)
  dynamic "origin" {
    for_each = var.s3_origin != null ? [var.s3_origin] : []

    content {
      origin_id                = origin.value.bucket_id
      domain_name              = origin.value.bucket_domain_name
      origin_path              = origin.value.origin_path
      origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id
    }
  }

  # Custom origins (ALB, API Gateway, etc.)
  dynamic "origin" {
    for_each = var.custom_origins

    content {
      origin_id   = origin.value.origin_id
      domain_name = origin.value.domain_name
      origin_path = origin.value.origin_path

      custom_origin_config {
        http_port              = origin.value.http_port
        https_port             = origin.value.https_port
        origin_protocol_policy = origin.value.origin_protocol
        origin_ssl_protocols   = origin.value.origin_ssl_protocols
      }
    }
  }

  # Default cache behavior
  default_cache_behavior {
    target_origin_id       = var.default_cache_behavior.target_origin_id
    viewer_protocol_policy = var.default_cache_behavior.viewer_protocol_policy
    allowed_methods        = var.default_cache_behavior.allowed_methods
    cached_methods         = var.default_cache_behavior.cached_methods
    compress               = var.default_cache_behavior.compress

    cache_policy_id          = var.default_cache_behavior.cache_policy_id
    origin_request_policy_id = var.default_cache_behavior.origin_request_policy_id

    default_ttl = var.default_cache_behavior.cache_policy_id == null ? var.default_cache_behavior.default_ttl : null
    max_ttl     = var.default_cache_behavior.cache_policy_id == null ? var.default_cache_behavior.max_ttl : null
    min_ttl     = var.default_cache_behavior.cache_policy_id == null ? var.default_cache_behavior.min_ttl : null

    dynamic "forwarded_values" {
      for_each = var.default_cache_behavior.cache_policy_id == null ? [1] : []

      content {
        query_string = false
        cookies {
          forward = "none"
        }
      }
    }
  }

  # Additional cache behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors

    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      compress               = ordered_cache_behavior.value.compress
      cache_policy_id        = ordered_cache_behavior.value.cache_policy_id

      dynamic "forwarded_values" {
        for_each = ordered_cache_behavior.value.cache_policy_id == null ? [1] : []

        content {
          query_string = false
          cookies {
            forward = "none"
          }
        }
      }
    }
  }

  # Custom error responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses

    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # SSL configuration
  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method             = var.certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != null ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.certificate_arn == null ? true : false
  }

  # NEW: Geo restriction (supports whitelist, blacklist, or none)
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction.restriction_type
      locations        = var.geo_restriction.restriction_type == "none" ? [] : var.geo_restriction.locations
    }
  }

  tags = var.tags
}
