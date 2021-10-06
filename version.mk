GIT_VERSION ?= $(shell git describe --tags --long --dirty)
VERSION ?= $(GIT_VERSION:v%=%)

.PHONY: version
version:  ## Print the parsed version of this project
	@ echo "$(VERSION)"
