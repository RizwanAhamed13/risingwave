#!/usr/bin/env bash
set -euo pipefail
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT
cargo test -p risingwave_meta --lib rpc::ddl_controller::tests::test_creation_admission -- --nocapture 2>&1 | tee "$output_file"
grep -Eq "test result: ok\. 7 passed; 0 failed" "$output_file"
