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

RUN wget -O /root/genesis.json https://github.com/ucpilabs/ucpiNetwork/releases/download/v1.2.0/genesis.json

ARG BUILD_VERSION="v0.0.0"
ENV VERSION=${BUILD_VERSION}

ENV SGX_MODE=HW
ENV ucpi_ENCLAVE_DIR=/usr/lib/


# workaround because paths seem kind of messed up
RUN cp /opt/sgxsdk/lib64/libsgx_urts_sim.so /usr/lib/libsgx_urts_sim.so
RUN cp /opt/sgxsdk/lib64/libsgx_uae_service_sim.so /usr/lib/libsgx_uae_service_sim.so

WORKDIR /root

RUN STORAGE_PATH=`echo ${VERSION} | sed -e 's/\.//g' | head -c 2` \
    && wget -O /usr/lib/librust_cosmwasm_enclave.signed.so https://engfilestorage.blob.core.windows.net/v$STORAGE_PATH/librust_cosmwasm_enclave.signed.so \
    &&  wget -O /usr/lib/librust_cosmwasm_query_enclave.signed.so https://engfilestorage.blob.core.windows.net/v$STORAGE_PATH/librust_cosmwasm_query_enclave.signed.so

# Copy over binaries from the build-env

COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/go-cosmwasm/target/release/libgo_cosmwasm.so /usr/lib/
# COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/go-cosmwasm/librust_cosmwasm_query_enclave.signed.so /usr/lib/
COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/ucpid /usr/bin/ucpid
COPY --from=build-env-rust-go /go/src/github.com/enigmampc/ucpiNetwork/ucpicli /usr/bin/ucpicli

COPY deployment/docker/node/mainnet_node.sh .

RUN chmod +x /usr/bin/ucpid
RUN chmod +x mainnet_node.sh

RUN ucpid completion > /root/ucpid_completion

RUN echo 'source /root/ucpid_completion' >> ~/.bashrc

RUN mkdir -p /root/.ucpid/.compute/
RUN mkdir -p /opt/ucpi/.sgx_ucpis/
RUN mkdir -p /root/.ucpid/.node/
RUN mkdir -p /root/config/



####### Node parameters

#ENV LD_LIBRARY_PATH=/opt/sgxsdk/libsgx-enclave-common/:/opt/sgxsdk/lib64/

# Run ucpid by default, omit entrypoint to ease using container with ucpicli
ENTRYPOINT ["/bin/bash", "mainnet_node.sh"]
