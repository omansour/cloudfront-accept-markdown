# --- IAM Role for Lambda ---

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "s3-read-content"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.content.arn}/*"
      }
    ]
  })
}

# --- Lambda Function ---

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/package"
  output_path = "${path.module}/../lambda/function.zip"
}

resource "aws_lambda_function" "converter" {
  function_name    = "${var.project_name}-converter-${random_id.suffix.hex}"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  role             = aws_iam_role.lambda.arn

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.content.id
    }
  }
}

# --- Lambda Function URL (AWS_IAM auth for OAC) ---

resource "aws_lambda_function_url" "converter" {
  function_name      = aws_lambda_function.converter.function_name
  authorization_type = "AWS_IAM"
}

# Allow CloudFront to invoke the Lambda Function URL
resource "aws_lambda_permission" "cloudfront_invoke_url" {
  statement_id           = "AllowCloudFrontInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.converter.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.main.arn
  function_url_auth_type = "AWS_IAM"
}

resource "aws_lambda_permission" "cloudfront_invoke" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.converter.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.main.arn
}

# Extract the domain from the Lambda Function URL
locals {
  lambda_url_domain = replace(replace(aws_lambda_function_url.converter.function_url, "https://", ""), "/", "")
}
