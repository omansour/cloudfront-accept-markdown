.PHONY: build deploy test destroy clean init

TERRAFORM_DIR := terraform
TOFU := tofu

build:
	@echo "==> Building Lambda package..."
	@bash scripts/build-lambda.sh

init: build
	@echo "==> Initializing OpenTofu..."
	@cd $(TERRAFORM_DIR) && $(TOFU) init

deploy: build
	@echo "==> Deploying with OpenTofu..."
	@cd $(TERRAFORM_DIR) && $(TOFU) init -upgrade
	@cd $(TERRAFORM_DIR) && $(TOFU) apply

test:
	@DOMAIN=$$(cd $(TERRAFORM_DIR) && $(TOFU) output -raw cloudfront_distribution_domain); \
	echo "==> Testing against $$DOMAIN"; \
	echo ""; \
	echo "--- 1. Normal HTML request ---"; \
	curl -s -o /dev/null -w "HTTP %{http_code} | Content-Type: %{content_type}\n" "https://$$DOMAIN/index.html"; \
	echo ""; \
	echo "--- 2. Markdown conversion ---"; \
	curl -s -D - -H "Accept: text/markdown" "https://$$DOMAIN/index.html" | head -30; \
	echo ""; \
	echo "--- 3. Second request (cache hit) ---"; \
	curl -s -o /dev/null -w "HTTP %{http_code} | X-Cache: %header{x-cache}\n" -H "Accept: text/markdown" "https://$$DOMAIN/index.html"

destroy:
	@echo "==> Destroying infrastructure..."
	@cd $(TERRAFORM_DIR) && $(TOFU) destroy

clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf lambda/package lambda/function.zip
	@rm -rf $(TERRAFORM_DIR)/.terraform $(TERRAFORM_DIR)/.terraform.lock.hcl
	@rm -f $(TERRAFORM_DIR)/terraform.tfstate*
