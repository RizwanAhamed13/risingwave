FROM public.ecr.aws/d3j8x8q7/olympus-base-rust:latest

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       cmake pkg-config protobuf-compiler libprotobuf-dev \
       libopenblas-dev liblapack-dev libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mv /root/.cargo /opt/cargo \
    && mv /root/.rustup /opt/rustup

ENV CARGO_HOME=/opt/cargo \
    RUSTUP_HOME=/opt/rustup \
    PATH=/opt/cargo/bin:${PATH}

RUN rustup component add rustfmt

COPY . .

ENV CARGO_INCREMENTAL=0 \
    CARGO_PROFILE_TEST_DEBUG=0

RUN cargo fetch --locked \
    && cargo build --locked -p risingwave_meta --lib

RUN if id -u model >/dev/null 2>&1; then \
        test "$(id -u model)" = "1000"; \
    else \
        useradd --create-home --uid 1000 --shell /bin/bash model; \
    fi \
    && chown -R model:model /app /opt/cargo /opt/rustup

ENV CARGO_NET_OFFLINE=true \
    HOME=/home/model

USER model
CMD ["/bin/bash"]
