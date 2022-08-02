# Base image
FROM rust-go-base-image AS build-env-rust-go

# Final image
FROM enigmampc/enigma-sgx-base:2004-1.1.3 as build-release

# wasmi-sgx-test script requirements
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    #### Base utilities ####
    jq \
    openssl \
    curl \
    wget \
    libsnappy-dev \
    libgflags-dev \
    bash-completion && \
    rm -rf /var/lib/apt/lists/*

RUN echo "source /etc/profile.d/bash_completion.sh" >> ~/.bashrc

RUN curl -sL https://deb.nodesource.com/setup_15.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs npm && \
    npm i -g local-cors-proxy

ARG SGX_MODE=SW
ENV SGX_MODE=${SGX_MODE}

ARG ucpi_NODE_TYPE=BOOTSTRAP
ENV ucpi_NODE_TYPE=${ucpi_NODE_TYPE}

ENV ucpi_ENCLAVE_DIR=/usr/lib/

# workaround because paths seem kind of messed up
RUN cp /opt/sgxsdk/lib64/libsgx_urts_sim.so /usr/lib/libsgx_urts_sim.so
RUN cp /opt/sgxsdk/lib64/libsgx_uae_service_sim.so /usr/lib/libsgx_uae_service_sim.so

# Install ca-certificates
WORKDIR /root

# Copy over binaries from the build-env
COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/go-cosmwasm/target/release/libgo_cosmwasm.so /usr/lib/
COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/go-cosmwasm/librust_cosmwasm_enclave.signed.so /usr/lib/
COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/go-cosmwasm/librust_cosmwasm_query_enclave.signed.so /usr/lib/
COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/ucpid /usr/bin/ucpid

COPY deployment/docker/bootstrap/bootstrap_init.sh .
COPY deployment/docker/node/node_init.sh .
COPY deployment/docker/startup.sh .
COPY deployment/docker/node_key.json .

RUN chmod +x /usr/bin/ucpid
RUN chmod +x bootstrap_init.sh
RUN chmod +x startup.sh
RUN chmod +x node_init.sh

RUN ucpid completion > /root/ucpid_completion

RUN echo 'source /root/ucpid_completion' >> ~/.bashrc

RUN mkdir -p /root/.ucpid/.compute/
RUN mkdir -p /opt/ucpi/.sgx_ucpis/
RUN mkdir -p /root/.ucpid/.node/
RUN mkdir -p /root/config/



####### Node parameters
ARG MONIKER=default
ARG CHAINID=ucpidev-1
ARG GENESISPATH=https://raw.githubusercontent.com/enigmampc/ucpiNetwork/master/ucpi-testnet-genesis.json
ARG PERSISTENT_PEERS=201cff36d13c6352acfc4a373b60e83211cd3102@bootstrap.southuk.azure.com:26656

ENV GENESISPATH="${GENESISPATH}"
ENV CHAINID="${CHAINID}"
ENV MONIKER="${MONIKER}"
ENV PERSISTENT_PEERS="${PERSISTENT_PEERS}"

#ENV LD_LIBRARY_PATH=/opt/sgxsdk/libsgx-enclave-common/:/opt/sgxsdk/lib64/

# Run ucpid by default, omit entrypoint to ease using container with ucpicli
ENTRYPOINT ["/bin/bash", "startup.sh"]
