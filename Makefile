PACKAGES=$(shell go list ./... | grep -v '/simulation')
VERSION ?= $(shell echo $(shell git describe --tags) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')
CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
DOCKER := $(shell which docker)
DOCKER_BUF := $(DOCKER) run --rm -v $(CURDIR):/workspace --workdir /workspace bufbuild/buf

LEDGER_ENABLED ?= true
BINDIR ?= $(GOPATH)/bin
BUILD_PROFILE ?= release
DEB_BIN_DIR ?= /usr/local/bin
DEB_LIB_DIR ?= /usr/lib

DB_BACKEND ?= goleveldb

SGX_MODE ?= HW
BRANCH ?= develop
DEBUG ?= 0
DOCKER_TAG ?= latest

ifeq ($(SGX_MODE), HW)
	ext := hw
else ifeq ($(SGX_MODE), SW)
	ext := sw
else
$(error SGX_MODE must be either HW or SW)
endif

ifeq ($(DB_BACKEND), rocksdb)
	DB_BACKEND = rocksdb
	DOCKER_CGO_LDFLAGS = "-L/usr/lib/x86_64-linux-gnu/ -lrocksdb -lstdc++ -llz4 -lm -lz -lbz2 -lsnappy"
	DOCKER_CGO_FLAGS = "-I/opt/rocksdb/include"
else ifeq ($(DB_BACKEND), cleveldb)
	DB_BACKEND = cleveldb
else ifeq ($(DB_BACKEND), goleveldb)
	DB_BACKEND = goleveldb
	DOCKER_CGO_LDFLAGS = ""
else
$(error DB_BACKEND must be one of: rocksdb/cleveldb/goleveldb)
endif

CUR_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error "gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false")
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning "OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988)")
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error "gcc not installed for ledger support, please install or set LEDGER_ENABLED=false")
      else
        build_tags += ledger
      endif
    endif
  endif
endif

IAS_BUILD = sw

ifeq ($(SGX_MODE), HW)
  ifneq (,$(findstring production,$(FEATURES)))
    IAS_BUILD = production
  else
    IAS_BUILD = develop
  endif

  build_tags += hw
endif

build_tags += $(IAS_BUILD)

ifeq ($(DB_BACKEND),rocksdb)
  build_tags += gcc
endif
ifeq ($(DB_BACKEND),cleveldb)
  build_tags += gcc
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
whitespace += $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=ucpiNetwork \
	-X github.com/cosmos/cosmos-sdk/version.AppName=ucpid \
	-X github.com/enigmampc/ucpiNetwork/cmd/ucpicli/version.ClientName=ucpicli \
	-X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
	-X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
	-X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags)"

ifeq ($(DB_BACKEND),cleveldb)
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
endif
ifeq ($(DB_BACKEND),rocksdb)
  CGO_ENABLED=1
  build_tags += rocksdb
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=rocksdb
  ldflags += -extldflags "-lrocksdb -llz4"
endif



ldflags += -s -w
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

GO_TAGS := $(build_tags)
# -ldflags
LD_FLAGS := $(ldflags)

all: build_all

vendor:
	cargo vendor third_party/vendor --manifest-path third_party/build/Cargo.toml

go.sum: go.mod
	@echo "--> Ensure dependencies have not been modified"
	GO111MODULE=on go mod verify

build_cli:
	go build -o ucpicli -mod=readonly -tags "$(GO_TAGS) ucpicli" -ldflags '$(LD_FLAGS)' ./cmd/ucpid

xgo_build_ucpicli: go.sum
	@echo "--> WARNING! This builds from origin/$(CURRENT_BRANCH)!"
	xgo --targets $(XGO_TARGET) -tags="$(GO_TAGS) ucpicli" -ldflags '$(LD_FLAGS)' --branch $(CURRENT_BRANCH) github.com/enigmampc/ucpiNetwork/cmd/ucpid
build_local_no_rust: bin-data-$(IAS_BUILD)
	cp go-cosmwasm/target/$(BUILD_PROFILE)/libgo_cosmwasm.so go-cosmwasm/api
	go build -mod=readonly -tags "$(GO_TAGS)" -ldflags '$(LD_FLAGS)' ./cmd/ucpid

build-linux: _build-linux build_local_no_rust build_cli
_build-linux: vendor
	BUILD_PROFILE=$(BUILD_PROFILE) FEATURES=$(FEATURES) FEATURES_U=$(FEATURES_U) $(MAKE) -C go-cosmwasm build-rust

build-linux-with-query: _build-linux-with-query build_local_no_rust build_cli
_build-linux-with-query: vendor
	BUILD_PROFILE=$(BUILD_PROFILE) FEATURES=$(FEATURES) FEATURES_U=query-node,$(FEATURES_U) $(MAKE) -C go-cosmwasm build-rust

build_windows_cli:
	$(MAKE) xgo_build_ucpicli XGO_TARGET=windows/amd64
	mv ucpid-windows-* ucpicli-windows-amd64.exe

build_macos_cli:
	$(MAKE) xgo_build_ucpicli XGO_TARGET=darwin/amd64
	mv ucpid-darwin-* ucpicli-macos-amd64

build_macos_arm64_cli:
	$(MAKE) xgo_build_ucpicli XGO_TARGET=darwin/arm64
	mv ucpid-darwin-* ucpicli-macos-arm64

build_linux_cli:
	$(MAKE) xgo_build_ucpicli XGO_TARGET=linux/amd64
	mv ucpid-linux-amd64 ucpicli-linux-amd64

build_linux_arm64_cli:
	$(MAKE) xgo_build_ucpicli XGO_TARGET=linux/arm64
	mv ucpid-linux-arm64 ucpicli-linux-arm64

build_all: build-linux build_windows_cli build_macos_cli build_linux_arm64_cli

deb: build-linux deb-no-compile

deb-no-compile:
    ifneq ($(UNAME_S),Linux)
		exit 1
    endif
	rm -rf /tmp/ucpiNetwork

	mkdir -p /tmp/ucpiNetwork/deb/$(DEB_BIN_DIR)
	cp -f ./ucpicli /tmp/ucpiNetwork/deb/$(DEB_BIN_DIR)/ucpicli
	cp -f ./ucpid /tmp/ucpiNetwork/deb/$(DEB_BIN_DIR)/ucpid
	chmod +x /tmp/ucpiNetwork/deb/$(DEB_BIN_DIR)/ucpid /tmp/ucpiNetwork/deb/$(DEB_BIN_DIR)/ucpicli

	mkdir -p /tmp/ucpiNetwork/deb/$(DEB_LIB_DIR)
	cp -f ./go-cosmwasm/api/libgo_cosmwasm.so ./go-cosmwasm/librust_cosmwasm_enclave.signed.so ./go-cosmwasm/librust_cosmwasm_query_enclave.signed.so /tmp/ucpiNetwork/deb/$(DEB_LIB_DIR)/
	chmod +x /tmp/ucpiNetwork/deb/$(DEB_LIB_DIR)/lib*.so

	mkdir -p /tmp/ucpiNetwork/deb/DEBIAN
	cp ./deployment/deb/control /tmp/ucpiNetwork/deb/DEBIAN/control
	printf "Version: " >> /tmp/ucpiNetwork/deb/DEBIAN/control
	printf "$(VERSION)" >> /tmp/ucpiNetwork/deb/DEBIAN/control
	echo "" >> /tmp/ucpiNetwork/deb/DEBIAN/control
	cp ./deployment/deb/postinst /tmp/ucpiNetwork/deb/DEBIAN/postinst
	chmod 755 /tmp/ucpiNetwork/deb/DEBIAN/postinst
	cp ./deployment/deb/postrm /tmp/ucpiNetwork/deb/DEBIAN/postrm
	chmod 755 /tmp/ucpiNetwork/deb/DEBIAN/postrm
	cp ./deployment/deb/triggers /tmp/ucpiNetwork/deb/DEBIAN/triggers
	chmod 755 /tmp/ucpiNetwork/deb/DEBIAN/triggers
	dpkg-deb --build /tmp/ucpiNetwork/deb/ .
	-rm -rf /tmp/ucpiNetwork

clean:
	-rm -rf /tmp/ucpiNetwork
	-rm -f ./ucpicli*
	-rm -f ./ucpid*
	-find -name '*.so' -delete
	-rm -f ./enigma-blockchain*.deb
	-rm -f ./SHA256SUMS*
	-rm -rf ./third_party/vendor/
	-rm -rf ./.sgx_ucpis/*
	-rm -rf ./x/compute/internal/keeper/.sgx_ucpis/*
	-rm -rf ./*.der
	-rm -rf ./x/compute/internal/keeper/*.der
	-rm -rf ./cmd/ucpid/ias_bin*
	$(MAKE) -C go-cosmwasm clean-all
	$(MAKE) -C cosmwasm/enclaves/test clean

build-rocksdb-image:
	docker build --build-arg BUILD_VERSION=${VERSION} -f deployment/dockerfiles/db-compile.Dockerfile -t enigmampc/rocksdb:${VERSION} .

build-localucpi:
	docker build --build-arg BUILD_VERSION=${VERSION} --build-arg SGX_MODE=SW --build-arg FEATURES_U="${FEATURES_U}" --build-arg FEATURES="${FEATURES},debug-print" -f deployment/dockerfiles/base.Dockerfile -t rust-go-base-image .
	docker build --build-arg SGX_MODE=SW --build-arg ucpi_NODE_TYPE=BOOTSTRAP --build-arg CHAIN_ID=ucpidev-1 -f deployment/dockerfiles/release.Dockerfile -t build-release .
	docker build --build-arg SGX_MODE=SW --build-arg ucpi_NODE_TYPE=BOOTSTRAP --build-arg CHAIN_ID=ucpidev-1 -f deployment/dockerfiles/dev-image.Dockerfile -t ghcr.io/ucpilabs/localucpi:${DOCKER_TAG} .

build-custom-dev-image:
    # .dockerignore excludes .so files so we rename these so that the dockerfile can find them
	cd go-cosmwasm/api && cp libgo_cosmwasm.so libgo_cosmwasm.so.x
	cd cosmwasm/enclaves/execute && cp librust_cosmwasm_enclave.signed.so librust_cosmwasm_enclave.signed.so.x
	docker build --build-arg SGX_MODE=SW --build-arg ucpi_NODE_TYPE=BOOTSTRAP -f deployment/dockerfiles/custom-node.Dockerfile -t enigmampc/ucpi-network-sw-dev-custom-bootstrap:${DOCKER_TAG} .
	docker build --build-arg SGX_MODE=SW --build-arg ucpi_NODE_TYPE=NODE -f deployment/dockerfiles/custom-node.Dockerfile -t enigmampc/ucpi-network-sw-dev-custom-node:${DOCKER_TAG} .
    # delete the copies created above
	rm go-cosmwasm/api/libgo_cosmwasm.so.x cosmwasm/enclaves/execute/librust_cosmwasm_enclave.signed.so.x

build-testnet: docker_base
	@mkdir build 2>&3 || true
	docker build --build-arg BUILD_VERSION=${VERSION} --build-arg SGX_MODE=HW --build-arg ucpi_NODE_TYPE=BOOTSTRAP -f deployment/dockerfiles/release.Dockerfile -t enigmampc/ucpi-network-bootstrap:v$(VERSION)-testnet .
	docker build --build-arg BUILD_VERSION=${VERSION} --build-arg SGX_MODE=HW --build-arg ucpi_NODE_TYPE=NODE -f deployment/dockerfiles/release.Dockerfile -t enigmampc/ucpi-network-node:v$(VERSION)-testnet .
	docker build --build-arg SGX_MODE=HW -f deployment/dockerfiles/build-deb.Dockerfile -t deb_build .
	docker run -e VERSION=${VERSION} -v $(CUR_DIR)/build:/build deb_build

build-mainnet-upgrade: docker_base
	@mkdir build 2>&3 || true
	docker build --build-arg BUILD_VERSION=${VERSION} -f deployment/dockerfiles/mainnet-upgrade-release.Dockerfile -t build-release:latest .
	docker build --build-arg BUILD_VERSION=${VERSION} --build-arg SGX_MODE=HW -f deployment/dockerfiles/build-deb-mainnet.Dockerfile -t deb_build .
	docker run -e VERSION=${VERSION} -v $(CUR_DIR)/build:/build deb_build
	docker tag build-release ghcr.io/ucpilabs/ucpi-network-node:$(VERSION)

build-mainnet: docker_base
	@mkdir build 2>&3 || true
	docker build --build-arg SGX_MODE=HW --build-arg ucpi_NODE_TYPE=BOOTSTRAP -f deployment/dockerfiles/release.Dockerfile -t enigmampc/ucpi-network-bootstrap:v$(VERSION)-mainnet .
	docker build --build-arg SGX_MODE=HW --build-arg ucpi_NODE_TYPE=NODE -f deployment/dockerfiles/release.Dockerfile -t enigmampc/ucpi-network-node:v$(VERSION)-mainnet .
	docker build --build-arg BUILD_VERSION=${VERSION} --build-arg SGX_MODE=HW -f deployment/dockerfiles/build-deb.Dockerfile -t deb_build .
	docker run -e VERSION=${VERSION} -v $(CUR_DIR)/build:/build deb_build

docker_base_rocksdb:
	docker build \
			--build-arg BUILD_VERSION=${VERSION} \
			--build-arg FEATURES=${FEATURES} \
			--build-arg FEATURES_U=${FEATURES_U} \
			--build-arg SGX_MODE=${SGX_MODE} \
			-f deployment/dockerfiles/base-rocksdb.Dockerfile \
			-t rust-go-base-image \
			.

docker_base_goleveldb: docker_base

docker_base_rust:
	docker build \
				--build-arg BUILD_VERSION=${VERSION} \
				--build-arg FEATURES=${FEATURES} \
				--build-arg FEATURES_U=${FEATURES_U} \
				--build-arg SGX_MODE=${SGX_MODE} \
				-f deployment/dockerfiles/base-rust.Dockerfile \
				-t rust-base-image \
				.

docker_base_go:
	docker build \
				--build-arg DB_BACKEND=${DB_BACKEND} \
				--build-arg BUILD_VERSION=${VERSION} \
				--build-arg FEATURES=${FEATURES} \
				--build-arg FEATURES_U=${FEATURES_U} \
				--build-arg SGX_MODE=${SGX_MODE} \
				--build-arg CGO_LDFLAGS=${DOCKER_CGO_LDFLAGS} \
				-f deployment/dockerfiles/base-go.Dockerfile \
				-t rust-go-base-image \
				.

docker_base: docker_base_rust docker_base_go

#ifeq ($(DB_BACKEND),rocksdb)
#docker_base: docker_base_rocksdb
#else
#docker_base: docker_base_goleveldb
#endif



docker_bootstrap: docker_base
	docker build --build-arg SGX_MODE=${SGX_MODE} --build-arg ucpi_NODE_TYPE=BOOTSTRAP -f deployment/dockerfiles/local-node.Dockerfile -t enigmampc/ucpi-network-bootstrap-${ext}:${DOCKER_TAG} .

docker_node: docker_base
	docker build --build-arg SGX_MODE=${SGX_MODE} --build-arg ucpi_NODE_TYPE=NODE -f deployment/dockerfiles/local-node.Dockerfile -t enigmampc/ucpi-network-node-${ext}:${DOCKER_TAG} .

docker_local_azure_hw: docker_base
	docker build --build-arg SGX_MODE=HW --build-arg ucpi_NODE_TYPE=NODE -f deployment/dockerfiles/local-node.Dockerfile -t ci-enigma-sgx-node .
	docker build --build-arg SGX_MODE=HW --build-arg ucpi_NODE_TYPE=BOOTSTRAP -f deployment/dockerfiles/local-node.Dockerfile -t ci-enigma-sgx-bootstrap .

docker_enclave_test:
	docker build --build-arg FEATURES="test ${FEATURES}" --build-arg SGX_MODE=${SGX_MODE} -f deployment/dockerfiles/enclave-test.Dockerfile -t rust-enclave-test .

# while developing:
build-enclave: vendor
	$(MAKE) -C cosmwasm/enclaves/execute enclave

# while developing:
check-enclave:
	$(MAKE) -C cosmwasm/enclaves/execute check

# while developing:
clippy-enclave:
	$(MAKE) -C cosmwasm/enclaves/execute clippy

# while developing:
clean-enclave:
	$(MAKE) -C cosmwasm/enclaves/execute clean

sanity-test:
	SGX_MODE=SW $(MAKE) build-linux
	cp ./cosmwasm/enclaves/execute/librust_cosmwasm_enclave.signed.so .
	SGX_MODE=SW ./cosmwasm/testing/sanity-test.sh

sanity-test-hw:
	$(MAKE) build-linux
	cp ./cosmwasm/enclaves/execute/librust_cosmwasm_enclave.signed.so .
	./cosmwasm/testing/sanity-test.sh

callback-sanity-test:
	SGX_MODE=SW $(MAKE) build-linux
	cp ./cosmwasm/enclaves/execute/librust_cosmwasm_enclave.signed.so .
	SGX_MODE=SW ./cosmwasm/testing/callback-test.sh

build-test-contract:
	# echo "" | sudo add-apt-repository ppa:hnakamur/binaryen
	# sudo apt update
	# sudo apt install -y binaryen
	$(MAKE) -C ./x/compute/internal/keeper/testdata/test-contract

prep-go-tests: build-test-contract
	# empty BUILD_PROFILE means debug mode which compiles faster
	SGX_MODE=SW $(MAKE) build-linux
	cp ./cosmwasm/enclaves/execute/librust_cosmwasm_enclave.signed.so ./x/compute/internal/keeper

go-tests: build-test-contract
	# empty BUILD_PROFILE means debug mode which compiles faster
	SGX_MODE=SW $(MAKE) build-linux
	cp ./cosmwasm/enclaves/execute/librust_cosmwasm_enclave.signed.so ./x/compute/internal/keeper
	rm -rf ./x/compute/internal/keeper/.sgx_ucpis
	mkdir -p ./x/compute/internal/keeper/.sgx_ucpis
	GOMAXPROCS=8 SGX_MODE=SW ucpi_SGX_STORAGE='./' go test -failfast -timeout 1200s -v ./x/compute/internal/... $(GO_TEST_ARGS)

go-tests-hw: build-test-contract
	# empty BUILD_PROFILE means debug mode which compiles faster
	SGX_MODE=HW $(MAKE) build-linux
	cp ./cosmwasm/enclaves/execute/librust_cosmwasm_enclave.signed.so ./x/compute/internal/keeper
	rm -rf ./x/compute/internal/keeper/.sgx_ucpis
	mkdir -p ./x/compute/internal/keeper/.sgx_ucpis
	GOMAXPROCS=8 SGX_MODE=HW go test -v ./x/compute/internal/... $(GO_TEST_ARGS)

# When running this more than once, after the first time you'll want to remove the contents of the `ffi-types`
# rule in the Makefile in `enclaves/execute`. This is to speed up the compilation time of tests and speed up the
# test debugging process in general.
.PHONY: enclave-tests
enclave-tests:
	$(MAKE) -C cosmwasm/enclaves/test run

build-all-test-contracts: build-test-contract
	# echo "" | sudo add-apt-repository ppa:hnakamur/binaryen
	# sudo apt update
	# sudo apt install -y binaryen
	cd ./cosmwasm/contracts/gov && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/gov/target/wasm32-unknown-unknown/release/gov.wasm -o ./x/compute/internal/keeper/testdata/gov.wasm

	cd ./cosmwasm/contracts/dist && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/dist/target/wasm32-unknown-unknown/release/dist.wasm -o ./x/compute/internal/keeper/testdata/dist.wasm

	cd ./cosmwasm/contracts/mint && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/mint/target/wasm32-unknown-unknown/release/mint.wasm -o ./x/compute/internal/keeper/testdata/mint.wasm

	cd ./cosmwasm/contracts/staking && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/staking/target/wasm32-unknown-unknown/release/staking.wasm -o ./x/compute/internal/keeper/testdata/staking.wasm

	cd ./cosmwasm/contracts/reflect && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/reflect/target/wasm32-unknown-unknown/release/reflect.wasm -o ./x/compute/internal/keeper/testdata/reflect.wasm

	cd ./cosmwasm/contracts/burner && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/burner/target/wasm32-unknown-unknown/release/burner.wasm -o ./x/compute/internal/keeper/testdata/burner.wasm

	cd ./cosmwasm/contracts/erc20 && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/erc20/target/wasm32-unknown-unknown/release/cw_erc20.wasm -o ./x/compute/internal/keeper/testdata/erc20.wasm

	cd ./cosmwasm/contracts/hackatom && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/hackatom/target/wasm32-unknown-unknown/release/hackatom.wasm -o ./x/compute/internal/keeper/testdata/contract.wasm
	cat ./x/compute/internal/keeper/testdata/contract.wasm | gzip > ./x/compute/internal/keeper/testdata/contract.wasm.gzip

build-erc20-contract: build-test-contract
	cd ./cosmwasm/contracts/erc20 && RUSTFLAGS='-C link-arg=-s' cargo build --release --target wasm32-unknown-unknown --locked
	wasm-opt -Os ./cosmwasm/contracts/erc20/target/wasm32-unknown-unknown/release/cw_erc20.wasm -o ./erc20.wasm

bin-data: bin-data-sw bin-data-develop bin-data-production

bin-data-sw:
	cd ./cmd/ucpid && go-bindata -o ias_bin_sw.go -prefix "../../ias_keys/sw_dummy/" -tags "!hw" ../../ias_keys/sw_dummy/...

bin-data-develop:
	cd ./cmd/ucpid && go-bindata -o ias_bin_dev.go -prefix "../../ias_keys/develop/" -tags "develop,hw" ../../ias_keys/develop/...

bin-data-production:
	cd ./cmd/ucpid && go-bindata -o ias_bin_prod.go -prefix "../../ias_keys/production/" -tags "production,hw" ../../ias_keys/production/...

# Before running this you might need to do:
# 1. sudo docker login -u ABC -p XYZ
# 2. sudo docker buildx create --use
ucpi-contract-optimizer:
	sudo docker buildx build --platform=linux/amd64,linux/arm64/v8 -f deployment/dockerfiles/ucpi-contract-optimizer.Dockerfile -t enigmampc/ucpi-contract-optimizer:${TAG} --push .

aesm-image:
	docker build -f deployment/dockerfiles/aesm.Dockerfile -t enigmampc/aesm .

###############################################################################
###                                Swagger                                  ###
###############################################################################

# Install the runsim binary with a temporary workaround of entering an outside
# directory as the "go get" command ignores the -mod option and will polute the
# go.{mod, sum} files.
#
# ref: https://github.com/golang/go/issues/30515
statik:
	@echo "Installing statik..."
	@go install github.com/rakyll/statik@v0.1.6

update-swagger-openapi-docs: statik proto-swagger-openapi-gen
	statik -src=client/docs/static/ -dest=client/docs -f -m
	@if [ -n "$(git status --porcelain)" ]; then \
        echo "\033[91mSwagger docs are out of sync!!!\033[0m";\
        exit 1;\
    else \
        echo "\033[92mSwagger docs are in sync\033[0m";\
    fi

.PHONY: update-swagger-openapi-docs statik

###############################################################################
###                                Protobuf                                 ###
###############################################################################

## proto-all: proto-gen proto-lint proto-check-breaking

# proto-gen:
#	@./scripts/protocgen.sh

# proto-lint:
#	@buf check lint --error-format=json

# proto-check-breaking:
#	@buf check breaking --against-input '.git#branch=master'

protoVer=v0.7

proto-all: proto-format proto-lint proto-gen proto-swagger-openapi-gen

proto-gen:
	@echo "Generating Protobuf files"
	$(DOCKER) run --rm -v $(CURDIR):/workspace --workdir /workspace tendermintdev/sdk-proto-gen:$(protoVer) sh ./scripts/protocgen.sh

proto-swagger-openapi-gen:
	@./scripts/protoc-swagger-openapi-gen.sh

proto-lint:
	@$(DOCKER_BUF) lint --error-format=json

.PHONY: proto-all proto-gen proto-swagger-openapi-gen proto-format proto-lint proto-check-breaking
