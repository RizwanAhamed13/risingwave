FROM public.ecr.aws/d3j8x8q7/olympus-base-rust:latest AS toolchain
WORKDIR /workspace/risingwave
RUN apt-get update && apt-get install -y --no-install-recommends cmake pkg-config protobuf-compiler libprotobuf-dev libopenblas-dev liblapack-dev libsasl2-dev && rm -rf /var/lib/apt/lists/*
RUN rustup component add rustfmt

FROM toolchain AS build
COPY . .
ENV CARGO_INCREMENTAL=0 CARGO_PROFILE_TEST_DEBUG=0
RUN cargo test -p risingwave_meta --lib rpc::ddl_controller::tests::test_creation_admission --no-run
RUN test_binary="$(find target/debug/deps -maxdepth 1 -type f -name 'risingwave_meta-*' -perm /111 -print -quit)" && test -n "$test_binary" && cp "$test_binary" /tmp/risingwave-meta-tests && rm -rf target

FROM toolchain
COPY --from=build /workspace/risingwave /workspace/risingwave
COPY --from=build /tmp/risingwave-meta-tests /opt/risingwave-meta-tests
ENV CARGO_NET_OFFLINE=true
RUN chmod +x /workspace/risingwave/olympus/test.sh /opt/risingwave-meta-tests
CMD ["/workspace/risingwave/olympus/test.sh"]
