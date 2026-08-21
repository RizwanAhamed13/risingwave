FROM public.ecr.aws/d3j8x8q7/olympus-base-rust:latest
WORKDIR /workspace/risingwave
COPY . .
RUN chmod +x /workspace/risingwave/olympus/test.sh
CMD ["/workspace/risingwave/olympus/test.sh"]
