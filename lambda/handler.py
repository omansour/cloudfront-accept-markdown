import json
import os
import re

import boto3
import html2text

S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
s3 = boto3.client("s3")


def handler(event, context):
    try:
        headers = event.get("headers", {})
        original_uri = headers.get("x-original-uri", "/")

        # Normalize S3 key
        key = original_uri.lstrip("/")
        if not key or key.endswith("/"):
            key = key + "index.html"

        # Fetch from S3
        try:
            response = s3.get_object(Bucket=S3_BUCKET_NAME, Key=key)
        except s3.exceptions.NoSuchKey:
            return {
                "statusCode": 404,
                "headers": {
                    "content-type": "text/plain; charset=utf-8",
                },
                "body": f"Not found: {key}",
            }

        content_type = response["ContentType"]
        if "text/html" not in content_type:
            return {
                "statusCode": 400,
                "headers": {
                    "content-type": "text/plain; charset=utf-8",
                },
                "body": f"Not an HTML document: {content_type}",
            }

        html_body = response["Body"].read().decode("utf-8")

        # Convert HTML to markdown
        converter = html2text.HTML2Text()
        converter.body_width = 0
        converter.inline_links = True
        converter.unicode_snob = True
        converter.protect_links = True
        converter.wrap_links = False

        markdown = converter.handle(html_body)

        # Strip excessive blank lines (3+ consecutive newlines → 2)
        markdown = re.sub(r"\n{3,}", "\n\n", markdown).strip() + "\n"

        # Estimate tokens (rough: 1 token ≈ 4 chars)
        token_estimate = len(markdown) // 4

        return {
            "statusCode": 200,
            "headers": {
                "content-type": "text/markdown; charset=utf-8",
                "vary": "accept",
                "x-markdown-tokens": str(token_estimate),
                "cache-control": "public, max-age=120",
            },
            "body": markdown,
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "content-type": "text/plain; charset=utf-8",
            },
            "body": "Internal error",
        }
