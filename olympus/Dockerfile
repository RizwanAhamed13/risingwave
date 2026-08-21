FROM public.ecr.aws/d3j8x8q7/olympus-base-rust:latest
WORKDIR /workspace/risingwave
RUN apt-get update && apt-get install -y --no-install-recommends protobuf-compiler libopenblas-dev liblapack-dev libsasl2-dev && rm -rf /var/lib/apt/lists/*
RUN rustup component add rustfmt
COPY . .
ENV CARGO_INCREMENTAL=0 CARGO_PROFILE_TEST_DEBUG=0
RUN cargo test -p risingwave_meta --lib rpc::ddl_controller::tests::test_creation_admission --no-run
ENV CARGO_NET_OFFLINE=true
RUN chmod +x /workspace/risingwave/olympus/test.sh
CMD ["/workspace/risingwave/olympus/test.sh"]
