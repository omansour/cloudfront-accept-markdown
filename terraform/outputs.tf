output "cloudfront_distribution_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "s3_bucket_name" {
  description = "S3 content bucket name"
  value       = aws_s3_bucket.content.id
}

output "lambda_function_url" {
  description = "Lambda Function URL"
  value       = aws_lambda_function_url.converter.function_url
}

output "test_commands" {
  description = "Test commands to verify the deployment"
  value       = <<-EOT
    # Normal HTML request:
    curl -v "https://${aws_cloudfront_distribution.main.domain_name}/index.html"

    # Markdown conversion:
    curl -v -H "Accept: text/markdown" "https://${aws_cloudfront_distribution.main.domain_name}/index.html"

    # Static asset (should NOT convert):
    curl -v -H "Accept: text/markdown" "https://${aws_cloudfront_distribution.main.domain_name}/style.css"
  EOT
}
