default: build

BINARY_NAME=terraform-provider-hashicups
DESTINATION=./bin/$(BINARY_NAME)
DESTINATION_2X=./bin-2x/$(BINARY_NAME)
MODE_PKG=terraform-provider-hashicups/internal/provider

LINKER_FLAGS=-s -w -X '$(MODE_PKG).FeatureMode=3x'
LINKER_FLAGS_2X=-s -w -X '$(MODE_PKG).FeatureMode=2x'

build:
	go build -ldflags "$(LINKER_FLAGS)" -o $(DESTINATION)

# Models the final 2.x release: the channel attribute is present in the schema
# so a module configuration validates, but a value is rejected at validate and
# plan time. See internal/provider/mode.go.
build-2x:
	mkdir -p ./bin-2x
	go build -ldflags "$(LINKER_FLAGS_2X)" -o $(DESTINATION_2X)

fmt:
	gofmt -s -w -e .

lint:
	golangci-lint run

.PHONY: build build-2x fmt lint
