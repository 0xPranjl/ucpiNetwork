# Final image
FROM build-release

ARG SGX_MODE=SW
ENV SGX_MODE=${SGX_MODE}
#
ARG ucpi_LOCAL_NODE_TYPE
ENV ucpi_LOCAL_NODE_TYPE=${ucpi_LOCAL_NODE_TYPE}

ENV PKG_CONFIG_PATH=""
ENV ucpi_ENCLAVE_DIR=/usr/lib/

COPY deployment/docker/sanity-test.sh /root/
RUN chmod +x /root/sanity-test.sh

COPY x/compute/internal/keeper/testdata/erc20.wasm erc20.wasm
RUN true
COPY deployment/ci/wasmi-sgx-test.sh .
RUN true
COPY deployment/ci/bootstrap_init.sh .
RUN true
COPY deployment/ci/node_init.sh .
RUN true
COPY deployment/ci/startup.sh .
RUN true
COPY deployment/ci/node_key.json .

RUN chmod +x /usr/bin/ucpid
# RUN chmod +x /usr/bin/ucpicli
RUN chmod +x wasmi-sgx-test.sh
RUN chmod +x bootstrap_init.sh
RUN chmod +x startup.sh
RUN chmod +x node_init.sh


#RUN mkdir -p /root/.ucpid/.compute/
#RUN mkdir -p /root/.sgx_ucpis/
#RUN mkdir -p /root/.ucpid/.node/

# Enable autocomplete
#RUN ucpicli completion > /root/ucpicli_completion
#RUN ucpid completion > /root/ucpid_completion
#
#RUN echo 'source /root/ucpid_completion' >> ~/.bashrc
#RUN echo 'source /root/ucpicli_completion' >> ~/.bashrc

#ENV LD_LIBRARY_PATH=/opt/sgxsdk/libsgx-enclave-common/:/opt/sgxsdk/lib64/

# Run ucpid by default, omit entrypoint to ease using container with ucpicli
ENTRYPOINT ["/bin/bash", "startup.sh"]
