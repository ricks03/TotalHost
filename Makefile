# vi:syntax=make

.ONESHELL:
.DEFAULT_GOAL := help
SHELL := /bin/bash
.SHELLFLAGS = -ec

TMP_DIR?=./tmp
BASE_DIR=$(shell pwd)
MAKEFILE_ABSPATH := $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
MAKEFILE_RELPATH := $(call MAKEFILE_ABSPATH)

HOST_PORT?=8080

.PHONY: help
help: ## print help message
	@echo "Usage: make <command>"
	@echo
	@echo "Available commands are:"
	@grep -E '^\S[^:]*:.*?## .*$$' $(MAKEFILE_RELPATH) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-4s\033[36m%-30s\033[0m %s\n", "", $$1, $$2}'
	@echo

.PHONY: clean
clean:
	echo Nothing to clean

.PHONY: clean-deps
clean-deps:
	echo No deps to clean

.PHONY: deps
deps:
	echo No dependencies to download

.PHONY: build
build: ## build the application
	docker build -t total-host .

.PHONY: run-shell
run-shell: ## run a shell in the docker container
	docker run --rm -it total-host bash

.PHONY: run-total-host
run-total-host: ## run the TotalHost server in the docker container
	# docker run --rm -t -p $(HOST_PORT):80 total-host
	docker-compose -f docker-compose-run.yml up --build --always-recreate-deps --force-recreate

.PHONY: lint
lint: ## run linting
	echo No linter configured

.PHONY: test
test: ## run unit tests
	PERLLIB=$(shell pwd)/scripts prove -v

.PHONY: ci-test
ci-test: ## ci target - run tests to generate coverage data
	echo No CI tests to run

.PHONY: acceptance-test
acceptance-test: build ## run acceptance tests
	docker-compose up --build --always-recreate-deps --force-recreate --exit-code-from tests
