SHELL := /usr/bin/bash
.SHELLFLAGS := -euo pipefail -c

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Available targets (in recommended order):"
	@echo
	@echo "  sanity     Check system assumptions (read-only)"

.PHONY: sanity
sanity:
	@bash ./scripts/sanity.sh
