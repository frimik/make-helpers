MAKEFILE_DIR_HELPERS_MK := $(dir $(realpath $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))))
FIRST_MAKEFILE := $(realpath $(firstword $(MAKEFILE_LIST)))
FIRST_MAKEFILE_DIR := $(dir $(FIRST_MAKEFILE))
GIT_ROOT ?= $(shell realpath $$(git rev-parse --show-toplevel))

####################
## Helper targets ##
####################
REPOSITORY_URL_RAW := $(shell git remote get-url origin)
REPOSITORY_URL_STRIP_GIT := $(patsubst git@%,%,$(patsubst %.git,%,$(REPOSITORY_URL_RAW)))
REPOSITORY_URL_STRIP_HTTPS := $(patsubst https://%,%,$(REPOSITORY_URL_STRIP_GIT))
REPOSITORY_URL_STRIP_COLON := $(subst :,/,$(REPOSITORY_URL_STRIP_HTTPS))
REPOSITORY_URL := "https://$(REPOSITORY_URL_STRIP_COLON)"

chglog_config: $(GIT_ROOT)/.chglog/config.yml
chglog_config: ## Generate $(GIT_ROOT)/.chglog/config.yml
$(GIT_ROOT)/.chglog/config.yml:
	mkdir -p $(GIT_ROOT)/.chglog
	cp -n $(MAKEFILE_DIR_HELPERS_MK)/scripts/chglog/* \
		$(GIT_ROOT)/.chglog/
	sed -e "s,{{REPOSITORY_URL}},$(REPOSITORY_URL)," \
		$(GIT_ROOT)/.chglog/config.tpl.yml \
		> $(GIT_ROOT)/.chglog/config.yml
	@ echo "Tried to guess the proper Repository URL: $(REPOSITORY_URL)"
	@ echo "If you're not happy with that, edit the '.chglog/config.yml' file"


.PHONY: authors
authors: ## Generate Authors
	git log --all --format='%aN <%aE>' -- . | sort -u | egrep -v noreply > AUTHORS

.PHONY: changelog
changelog: NEXT ?=
changelog: $(GIT_ROOT)/.chglog/config.yml
changelog: ## Generate Changelog
	@ $(MAKE) --no-print-directory log-$@
	cd $(GIT_ROOT) && git-chglog --tag-filter-pattern v[0-9]+.[0-9]+.[0-9]+$$ --output CHANGELOG.md $(NEXT)
	@ git add $(GIT_ROOT)/CHANGELOG.md
	@ git commit -m "Update Changelog" $(GIT_ROOT)/CHANGELOG.md
	@ echo "I've now committed a new CHANGELOG.md. It's up to you to push it."

.PHONY: changelog
changelog-local: NEXT ?=
changelog-local: $(GIT_ROOT)/.chglog/config.yml
changelog-local: ## Generate Changelog in the current directory
	@ $(MAKE) --no-print-directory log-$@
	git-chglog --config $(GIT_ROOT)/.chglog/config.yml --tag-filter-pattern v[0-9]+.[0-9]+.[0-9]+$$ --path . --output CHANGELOG.md $(NEXT)
	@ git add CHANGELOG.md
	@ git commit -m "Update Changelog"
	@ echo "I've now committed a new CHANGELOG.md. It's up to you to push it."

.PHONY: git-chglog
git-chglog: .chglog/config.yml
ifeq (, $(shell which git-chglog))
	go get -u github.com/git-chglog/git-chglog/cmd/git-chglog
endif

.PHONY: goimports
goimports:
ifeq (, $(shell which goimports))
	GO111MODULE=off go get -u golang.org/x/tools/cmd/goimports
endif

.PHONY: golangci
golangci:
ifeq (, $(shell which golangci-lint))
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s  -- -b $(shell go env GOPATH)/bin $(GOLANGCI_VERSION)
endif

.PHONY: gox
gox:
ifeq (, $(shell which gox))
	GO111MODULE=off go get -u github.com/mitchellh/gox
endif

.PHONY: tools
tools: ## Install required tools
	@ $(MAKE) --no-print-directory log-$@
	@ $(MAKE) --no-print-directory git-chglog goimports golangci gox

########################################################################
## Self-Documenting Makefile Help                                     ##
## https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html ##
########################################################################
.PHONY: help
help:
	@awk -F ':|##' \
		'/^[^\t].+?:.*?##/ {\
			printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
			}' $(MAKEFILE_LIST)

log-%:
	@ grep -h -E '^$*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m==> %s\033[0m\n", $$2}'


context.tf: ## Add/Update the terraform context.tf file
	curl -o context.tf -fsSL https://raw.githubusercontent.com/cloudposse/terraform-null-label/master/exports/context.tf
	git ls-files --error-unmatch context.tf 2>/dev/null || git add context.tf
	@if [[ -d examples/complete ]]; then \
		cp -p context.tf examples/complete/context.tf ; \
	fi

.PHONY: context.tf
