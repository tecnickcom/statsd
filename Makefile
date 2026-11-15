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
CURRENTDIR=$(CURDIR)/

# Target directory
TARGETDIR=target

# Directory where to store binary utility tools
BINUTIL=$(TARGETDIR)/binutil

# Directory of the separate module declaring the build tools.
# The tools are kept out of the root go.mod so that consumers of this library
# do not carry them in their module graph.
GOTOOLSDIR=$(CURDIR)/resources/tools

# sed argument for in-place substitutions
SEDINPLACE=-i
ifeq ($(shell uname -s),Darwin)
	SEDINPLACE=-i ''
endif

# GO lang path
ifeq ($(GOPATH),)
	# extract the GOPATH
	GOPATH=$(shell echo "$(CURDIR)" | sed 's|/src/.*||')
endif

# Add the GO binary dir and the local tool dir in the PATH
export PATH := $(CURDIR)/$(BINUTIL):$(GOPATH)/bin:$(PATH)

# Docker tag
DOCKERTAG=$(VERSION)-$(RELEASE)

# Docker command
ifeq ($(DOCKER),)
	DOCKER=$(shell which docker)
endif

# Common commands
GO=GOPATH="$(GOPATH)" $(shell which go)
# Commands for the tools module. It may require a newer Go than this module, so
# it selects its own toolchain regardless of the GOTOOLCHAIN in the environment.
GOTOOLSMOD=GOTOOLCHAIN=auto $(GO) -C "$(GOTOOLSDIR)"
GOVERSION=${shell go version | grep -Eo '(go[0-9]+.[0-9]+)'}
GOFMT=$(shell which gofmt)
GOTEST=$(GO) test
GODOC=GOPATH="$(GOPATH)" $(shell which godoc)
GOLANGCILINT=$(BINUTIL)/golangci-lint
GOLANGCILINTVERSION=v2.15.0
GOJUNITREPORT=$(BINUTIL)/go-junit-report

# Directory containing the source code
SRCDIR=./

# List of packages
GOPKGS=$(shell $(GO) list $(SRCDIR)/...)

# Enable junit report when not in LOCAL mode
ifeq ($(strip $(DEVMODE)),LOCAL)
	TESTEXTRACMD=&& $(GO) tool cover -func=$(TARGETDIR)/report/coverage.out
else
	TESTEXTRACMD=2>&1 | tee >($(GOJUNITREPORT) > $(TARGETDIR)/test/report.xml); test $${PIPESTATUS[0]} -eq 0
endif


# --- MAKE TARGETS ---

# Display general help about this command
.PHONY: help
help:
	@if [ -t 1 ] && [ -z "$${NO_COLOR:-}" ]; then \
		B=$$(printf '\033[1m'); C=$$(printf '\033[36m'); Y=$$(printf '\033[33m'); D=$$(printf '\033[2m'); R=$$(printf '\033[0m'); \
	else \
		B=''; C=''; Y=''; D=''; R=''; \
	fi; \
	printf "\n%s%s%s %s(v%s)%s\n" "$$B" "$(PROJECT)" "$$R" "$$D" "$(VERSION)" "$$R"; \
	printf "%sGOPATH=%s%s\n" "$$D" "$(GOPATH)" "$$R"; \
	printf "\n%sUsage:%s make %s<target>%s\n\n" "$$Y" "$$R" "$$C" "$$R"; \
	printf "%sTargets:%s\n" "$$Y" "$$R"; \
	awk -v c="$$C" -v r="$$R" '/^## /{desc=substr($$0,4)} /^\.PHONY:/{if(NF>1){if(desc){n++; t[n]=$$2; d[n]=desc; if(length($$2)>w) w=length($$2)} desc=""}} END{fmt="  %s%-" w "s%s  %s\n"; for(i=1;i<=n;i++) printf fmt,c,t[i],r,d[i]}' Makefile; \
	printf "\n%sTo test and build everything from scratch:%s make %sx%s\n\n" "$$D" "$$R" "$$C" "$$R"

# Alias for help target
all: help

# Alias to test and build everything from scratch
.PHONY: x
x:
	DEVMODE=LOCAL $(MAKE) format clean mod deps generate qa

## Remove any build artifact
.PHONY: clean
clean:
	rm -rf "$(TARGETDIR)"

## Generate the coverage report
.PHONY: coverage
coverage: ensuretarget
	$(GO) tool cover -html="$(TARGETDIR)/report/coverage.out" -o "$(TARGETDIR)/report/coverage.html"

## Build everything inside a Docker container
.PHONY: dbuild
dbuild: dockerdev
	@mkdir -p "$(TARGETDIR)"
	@rm -rf "$(TARGETDIR)/"*
	@echo 0 > "$(TARGETDIR)/make.exit"
	CVSPATH=$(CVSPATH) VENDOR=$(LCVENDOR) PROJECT=$(PROJECT) MAKETARGET='$(MAKETARGET)' DOCKERTAG='$(DOCKERTAG)' "$(CURRENTDIR)dockerbuild.sh"
	@exit `cat $(TARGETDIR)/make.exit`

## Get the test dependencies
.PHONY: deps
deps: ensuretarget
	curl --silent --show-error --fail --location "https://golangci-lint.run/install.sh" | sh -s -- -b "$(BINUTIL)" $(GOLANGCILINTVERSION)

## Build a base development Docker image
.PHONY: dockerdev
dockerdev:
	$(DOCKER) build --pull --tag "${LCVENDOR}/dev_${PROJECT}" --file ./resources/docker/Dockerfile.dev ./resources/docker/

## Create the trget directories if missing
.PHONY: ensuretarget
ensuretarget:
	@mkdir -p "$(TARGETDIR)/test"
	@mkdir -p "$(TARGETDIR)/report"
	@mkdir -p "$(TARGETDIR)/binutil"

## Format the source code
.PHONY: format
format:
	@find "$(SRCDIR)" -type f -name "*.go" -exec $(GOFMT) -s -w {} \;

## Generate test mocks
.PHONY: generate
generate:
	@find "$(SRCDIR)" -type f -name "*mock_test.go" -exec rm {} \;
	$(GO) generate $(GOPKGS)

## Execute multiple linter tools
.PHONY: linter
linter:
	@echo -e "\n\n>>> START: Static code analysis <<<\n\n"
	$(GOLANGCILINT) run --max-issues-per-linter 0 --max-same-issues 0 "$(SRCDIR)/..."
	@echo -e "\n\n>>> END: Static code analysis <<<\n\n"

## Download dependencies
.PHONY: mod
mod: gotools
# Without arguments this downloads the modules required to build and test this
# module. The "all" pattern additionally walks the module graph and writes
# go.sum entries for modules no package here reaches.
	$(GO) mod download

## Check that go.mod and go.sum are tidy
.PHONY: modcheck
modcheck:
# Reports what "go mod tidy" would change and fails if anything would, without
# writing to go.mod or go.sum.
	$(GO) mod tidy -diff -compat=$(shell sed -n -E 's/^go ([0-9]+\.[0-9]+).*/\1/p' go.mod)
	$(GOTOOLSMOD) mod tidy -diff

## Run all tests and static analysis tools
.PHONY: qa
qa: linter test coverage

## Tag the Git repository
.PHONY: tag
tag:
	git tag -a "v$(VERSION)" -m "Version $(VERSION)" && \
	git push origin --tags

## Run the unit tests
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

## Get the go tools
.PHONY: gotools
gotools: ensuretarget
	GOBIN="$(CURDIR)/$(BINUTIL)" $(GOTOOLSMOD) install tool

## Update everything
.PHONY: updateall
updateall: updatego updatelint updatemod

## Update go version
.PHONY: updatego
updatego:
	$(eval LAST_GO_TOOLCHAIN=$(shell curl -s https://go.dev/dl/ | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+\.linux-amd64\.tar\.gz' | head -n 1 | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+'))
# The `go` directive is the minimum version a consumer needs and is set
# deliberately: it is not bumped here. Only the toolchain is updated.
	sed $(SEDINPLACE) "s|^toolchain go[0-9]*\.[0-9]*\.[0-9]*$$|toolchain ${LAST_GO_TOOLCHAIN}|g" go.mod "$(GOTOOLSDIR)/go.mod"

## Update linter version
.PHONY: updatelint
updatelint:
	$(eval LAST_GOLANGCILINT_VERSION=$(shell curl -sL https://github.com/golangci/golangci-lint/releases/latest | sed -n 's/.*<title>Release \(v[0-9]*\.[0-9]*\.[0-9]*\).*/\1/p'))
	sed $(SEDINPLACE) "s|^GOLANGCILINTVERSION=v[0-9]*\.[0-9]*\.[0-9]*$$|GOLANGCILINTVERSION=${LAST_GOLANGCILINT_VERSION}|g" Makefile

## Update dependencies
.PHONY: updatemod
updatemod: mod
	$(GO) get -t -u ./... && \
	$(GO) mod tidy -compat=$(shell sed -n -E 's/^go ([0-9]+\.[0-9]+).*/\1/p' go.mod)
	$(GOTOOLSMOD) get -u tool && \
	$(GOTOOLSMOD) mod tidy

## Increase the patch number in the VERSION file
.PHONY: versionup
versionup:
	echo ${VERSION} | gawk -F. '{printf("%d.%d.%d\n",$$1,$$2,(($$3+1)));}' > VERSION
