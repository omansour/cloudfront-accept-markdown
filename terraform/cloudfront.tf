# --- OAC for S3 ---

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project_name}-s3-oac-${random_id.suffix.hex}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- Cache Policy (includes x-content-format for cache key separation) ---

resource "aws_cloudfront_cache_policy" "markdown_aware" {
  name        = "${var.project_name}-markdown-aware-${random_id.suffix.hex}"
  default_ttl = 120
  max_ttl     = 120
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["x-content-format"]
      }
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# --- CloudFront Function ---

resource "aws_cloudfront_function" "viewer_request" {
  name    = "${var.project_name}-viewer-request-${random_id.suffix.hex}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = replace(file("${path.module}/../cloudfront-function/viewer-request.js"), "LAMBDA_FUNCTION_URL_DOMAIN", local.lambda_url_domain)
}

# --- CloudFront Distribution ---

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = "Markdown for Agents - ${random_id.suffix.hex}"

  # Origin 1: S3 bucket (primary)
  origin {
    domain_name              = aws_s3_bucket.content.bucket_regional_domain_name
    origin_id                = "s3-content"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # Origin 2: S3 bucket again (failover target)
  origin {
    domain_name              = aws_s3_bucket.content.bucket_regional_domain_name
    origin_id                = "s3-content-failover"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # Origin Group: primary S3 with failover to S3
  # CF Function rewrites primary origin to Lambda for markdown requests.
  # If Lambda fails (5xx), CloudFront falls back to secondary (S3 HTML).
  origin_group {
    origin_id = "s3-with-failover"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "s3-content"
    }

    member {
      origin_id = "s3-content-failover"
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-with-failover"
    cache_policy_id        = aws_cloudfront_cache_policy.markdown_aware.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.viewer_request.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
