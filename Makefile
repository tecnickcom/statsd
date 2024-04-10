# MAKEFILE
#
# @author      Nicola Asuni
# @link        https://github.com/tecnickcom/statsd
# ------------------------------------------------------------------------------

SHELL=/bin/bash
.SHELLFLAGS=-o pipefail -c

# Project owner
OWNER=tecnickcom

# Project vendor
VENDOR=${OWNER}

# Lowercase VENDOR name for Docker
LCVENDOR=$(shell echo "${VENDOR}" | tr '[:upper:]' '[:lower:]')

# CVS path (path to the parent dir containing the project)
CVSPATH=github.com/${VENDOR}

# Project name
PROJECT=statsd

# Project version
VERSION=$(shell cat VERSION)

# Project release number (packaging build number)
RELEASE=$(shell cat RELEASE)

# Current directory
CURRENTDIR=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))

# Target directory
TARGETDIR=$(CURRENTDIR)target

# Directory where to store binary utility tools
BINUTIL=$(TARGETDIR)/binutil

# GO lang path
ifeq ($(GOPATH),)
	# extract the GOPATH
	GOPATH=$(firstword $(subst /src/, ,$(CURRENTDIR)))
endif

# Add the GO binary dir in the PATH
export PATH := $(GOPATH)/bin:$(PATH)

# Docker tag
DOCKERTAG=$(VERSION)-$(RELEASE)

# Docker command
ifeq ($(DOCKER),)
	DOCKER=$(shell which docker)
endif

# Common commands
GO=GOPATH=$(GOPATH) GOPRIVATE=$(CVSPATH) $(shell which go)
GOVERSION=${shell go version | grep -Po '(go[0-9]+.[0-9]+)'}
GOFMT=$(shell which gofmt)
GOTEST=GOPATH=$(GOPATH) $(shell which gotest)
GODOC=GOPATH=$(GOPATH) $(shell which godoc)
GOLANGCILINT=$(BINUTIL)/golangci-lint
GOLANGCILINTVERSION=v1.57.2

# Directory containing the source code
SRCDIR=./

# List of packages
GOPKGS=$(shell $(GO) list $(SRCDIR)/...)

# Enable junit report when not in LOCAL mode
ifeq ($(strip $(DEVMODE)),LOCAL)
	TESTEXTRACMD=&& $(GO) tool cover -func=$(TARGETDIR)/report/coverage.out
else
	TESTEXTRACMD=2>&1 | tee >(PATH=$(GOPATH)/bin:$(PATH) go-junit-report > $(TARGETDIR)/test/report.xml); test $${PIPESTATUS[0]} -eq 0
endif


# --- MAKE TARGETS ---

# Display general help about this command
.PHONY: help
help:
	@echo ""
	@echo "$(PROJECT) Makefile."
	@echo "GOPATH=$(GOPATH)"
	@echo "The following commands are available:"
	@echo ""
	@echo "    make clean     : Remove any build artifact"
	@echo "    make coverage  : Generate the coverage report"
	@echo "    make dbuild    : Build everything inside a Docker container"
	@echo "    make deps      : Get dependencies"
	@echo "    make format    : Format the source code"
	@echo "    make generate  : Generate go code automatically"
	@echo "    make linter    : Check code against multiple linters"
	@echo "    make mod       : Download dependencies"
	@echo "    make modupdate : Update dependencies"
	@echo "    make qa        : Run all tests and static analysis tools"
	@echo "    make tag       : Tag the Git repository"
	@echo "    make test      : Run unit tests"
	@echo ""
	@echo "Use DEVMODE=LOCAL for human friendly output."
	@echo ""
	@echo "To test and build everything from scratch:"
	@echo "    DEVMODE=LOCAL make format clean mod deps generate qa"
	@echo "or use the shortcut:"
	@echo "    make x"
	@echo ""

# Alias for help target
all: help

# Alias to test and build everything from scratch
.PHONY: x
x:
	DEVMODE=LOCAL $(MAKE) format clean mod deps generate qa

# Remove any build artifact
.PHONY: clean
clean:
	rm -rf $(TARGETDIR)

# Generate the coverage report
.PHONY: coverage
coverage: ensuretarget
	$(GO) tool cover -html=$(TARGETDIR)/report/coverage.out -o $(TARGETDIR)/report/coverage.html

# Build everything inside a Docker container
.PHONY: dbuild
dbuild: dockerdev
	@mkdir -p $(TARGETDIR)
	@rm -rf $(TARGETDIR)/*
	@echo 0 > $(TARGETDIR)/make.exit
	CVSPATH=$(CVSPATH) VENDOR=$(LCVENDOR) PROJECT=$(PROJECT) MAKETARGET='$(MAKETARGET)' DOCKERTAG='$(DOCKERTAG)' $(CURRENTDIR)dockerbuild.sh
	@exit `cat $(TARGETDIR)/make.exit`

# Get the test dependencies
.PHONY: deps
deps: ensuretarget
	curl --silent --show-error --fail --location "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" | sh -s -- -b $(BINUTIL) $(GOLANGCILINTVERSION)
	$(GO) install github.com/rakyll/gotest
	$(GO) install github.com/jstemmer/go-junit-report
	$(GO) install github.com/golang/mock/mockgen

# Build a base development Docker image
.PHONY: dockerdev
dockerdev:
	$(DOCKER) build --pull --tag ${LCVENDOR}/dev_${PROJECT} --file ./resources/docker/Dockerfile.dev ./resources/docker/

# Create the trget directories if missing
.PHONY: ensuretarget
ensuretarget:
	@mkdir -p $(TARGETDIR)/test
	@mkdir -p $(TARGETDIR)/report
	@mkdir -p $(TARGETDIR)/binutil

# Format the source code
.PHONY: format
format:
	@find $(SRCDIR) -type f -name "*.go" -exec $(GOFMT) -s -w {} \;

# Generate test mocks
.PHONY: generate
generate:
	@find $(SRCDIR) -type f -name "*mock_test.go" -exec rm {} \;
	$(GO) generate $(GOPKGS)

# Execute multiple linter tools
.PHONY: linter
linter:
	@echo -e "\n\n>>> START: Static code analysis <<<\n\n"
	$(GOLANGCILINT) run --exclude-use-default=false --max-issues-per-linter 0 --max-same-issues 0 $(SRCDIR)/...
	@echo -e "\n\n>>> END: Static code analysis <<<\n\n"

# Download dependencies
.PHONY: mod
mod:
	$(GO) mod download all

# Update dependencies
.PHONY: modupdate
modupdate:
	# $(GO) get $(shell $(GO) list -f '{{if not (or .Main .Indirect)}}{{.Path}}{{end}}' -m all)
	$(GO) get -t -u -d ./... && go mod tidy -compat=$(shell grep -oP 'go \K[0-9]+\.[0-9]+' go.mod)

# Run all tests and static analysis tools
.PHONY: qa
qa: linter test coverage

# Tag the Git repository
.PHONY: tag
tag:
	git tag -a "v$(VERSION)" -m "Version $(VERSION)" && \
	git push origin --tags

# Run the unit tests
.PHONY: test
test: ensuretarget
	@echo -e "\n\n>>> START: Unit Tests <<<\n\n"
	$(GOTEST) \
	-shuffle=on \
	-tags=unit,benchmark \
	-covermode=atomic \
	-bench=. \
	-race \
	-failfast \
	-coverprofile=$(TARGETDIR)/report/coverage.out \
	-v $(GOPKGS) $(TESTEXTRACMD)
	@echo -e "\n\n>>> END: Unit Tests <<<\n\n"
