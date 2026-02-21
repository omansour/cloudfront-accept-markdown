#!/usr/bin/env python3
"""Demo script for Accept: text/markdown CloudFront conversion."""

import argparse
import subprocess
import sys
import time
import urllib.request

# ANSI escape codes
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"
GREEN = "\033[32m"
RED = "\033[31m"
CYAN = "\033[36m"
YELLOW = "\033[33m"

CHECK = f"{GREEN}\u2714{RESET}"
CROSS = f"{RED}\u2718{RESET}"


def get_domain():
    """Get CloudFront domain from tofu output."""
    result = subprocess.run(
        ["tofu", "output", "-raw", "cloudfront_distribution_domain"],
        cwd="terraform",
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"{RED}Failed to get domain from tofu output:{RESET}")
        print(result.stderr.strip())
        sys.exit(1)
    return result.stdout.strip()


def request(url, headers=None):
    """Make an HTTP request and return (response, body, elapsed_ms)."""
    req = urllib.request.Request(url, headers=headers or {})
    start = time.monotonic()
    resp = urllib.request.urlopen(req)
    body = resp.read().decode("utf-8", errors="replace")
    elapsed = (time.monotonic() - start) * 1000
    return resp, body, elapsed


def header_line(label, value):
    """Format a header display line."""
    return f"  {DIM}{label}:{RESET} {value}"


def print_banner(domain):
    print()
    print(f"  {BOLD}Accept: text/markdown{RESET} {DIM}\u2014 CloudFront Demo{RESET}")
    print(f"  {DIM}https://{domain}{RESET}")
    print(f"  {DIM}{'─' * 48}{RESET}")
    print()


def test_html(domain):
    """Test 1: Normal HTML request."""
    url = f"https://{domain}/index.html"
    resp, body, ms = request(url)

    status = resp.status
    content_type = resp.headers.get("Content-Type", "")
    passed = status == 200 and "text/html" in content_type

    x_cache = resp.headers.get("X-Cache", "unknown")
    icon = CHECK if passed else CROSS
    print(f"  {BOLD}1. Normal HTML Request{RESET}  {icon}")
    print(header_line("Status", status))
    print(header_line("Content-Type", content_type))
    print(header_line("X-Cache", x_cache))
    print(header_line("Response", f"{ms:.0f}ms"))
    print()
    return passed


def test_markdown(domain):
    """Test 2: Markdown conversion."""
    url = f"https://{domain}/index.html"
    resp, body, ms = request(url, headers={"Accept": "text/markdown"})

    status = resp.status
    content_type = resp.headers.get("Content-Type", "")
    tokens = resp.headers.get("x-markdown-tokens", "?")
    passed = status == 200 and "text/markdown" in content_type

    x_cache = resp.headers.get("X-Cache", "unknown")
    icon = CHECK if passed else CROSS
    print(f"  {BOLD}2. Markdown Conversion{RESET}  {icon}")
    print(header_line("Status", status))
    print(header_line("Content-Type", content_type))
    print(header_line("Tokens", f"~{tokens}"))
    print(header_line("X-Cache", x_cache))
    print(header_line("Response", f"{ms:.0f}ms"))
    print()

    # Show body preview
    lines = body.splitlines()
    preview = lines[:15]
    print(f"  {DIM}{'─' * 40}{RESET}")
    for line in preview:
        print(f"  {CYAN}{line}{RESET}")
    if len(lines) > 15:
        print(f"  {DIM}... ({len(lines) - 15} more lines){RESET}")
    print(f"  {DIM}{'─' * 40}{RESET}")
    print()
    return passed


def test_cache(domain):
    """Test 3: Cache behavior on repeated markdown request."""
    url = f"https://{domain}/index.html"
    resp, body, ms = request(url, headers={"Accept": "text/markdown"})

    status = resp.status
    content_type = resp.headers.get("Content-Type", "")
    tokens = resp.headers.get("x-markdown-tokens", "?")
    x_cache = resp.headers.get("X-Cache", "unknown")
    passed = status == 200 and "Hit" in x_cache

    icon = CHECK if passed else CROSS
    print(f"  {BOLD}3. Cache Behavior{RESET}  {icon}")
    print(header_line("Status", status))
    print(header_line("Content-Type", content_type))
    print(header_line("Tokens", f"~{tokens}"))
    print(header_line("X-Cache", x_cache))
    print(header_line("Response", f"{ms:.0f}ms"))
    if not passed and "Hit" not in x_cache:
        print(f"  {DIM}(may need a second run for cache to warm){RESET}")
    print()
    return passed


def main():
    parser = argparse.ArgumentParser(description="Demo: Accept text/markdown")
    parser.add_argument("--domain", help="CloudFront domain (default: from tofu output)")
    args = parser.parse_args()

    domain = args.domain or get_domain()
    print_banner(domain)

    results = [
        test_html(domain),
        test_markdown(domain),
        test_cache(domain),
    ]

    passed = sum(results)
    total = len(results)
    color = GREEN if passed == total else (YELLOW if passed > 0 else RED)
    print(f"  {color}{BOLD}{passed}/{total} tests passed{RESET}")
    print()

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
