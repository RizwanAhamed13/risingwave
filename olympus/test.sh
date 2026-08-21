#!/usr/bin/env bash
set -euo pipefail
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT
cargo test -p risingwave_meta --lib rpc::ddl_controller::tests::test_creation_admission -- --nocapture 2>&1 | tee "$output_file"
grep -Eq "test result: ok\. 7 passed; 0 failed" "$output_file"
python3 - <<'PY'
from pathlib import Path
ddl = Path("src/meta/src/rpc/ddl_controller.rs").read_text()
stream = Path("src/meta/src/stream/stream_manager.rs").read_text()
background_start = stream.index("CreateType::Background => {")
background_end = stream.index("CreateType::Foreground => {", background_start)
background = stream[background_start:background_end]
assert ".take_permit(job_id)" in background, "background request did not transfer admission ownership"
assert ".track_creating_job_permit(" in background, "background request did not install a lifecycle tracker"
tracker_start = stream.index("pub(crate) fn track_creating_job_permit")
tracker_end = stream.index("async fn provision_serverless_backfill_resource_group", tracker_start)
tracker = stream[tracker_start:tracker_end]
for token in ("wait_streaming_job_finished", "is_catalog_id_not_found", "Err(err) =>", "sleep(", "drop(permit)"):
    assert token in tracker, f"lifecycle tracker missing {token}"
constructor_start = ddl.index("pub async fn new(")
constructor = ddl[constructor_start:constructor_start + 18000]
for token in ("list_creating_jobs(false, None)", "claim_recovered(job_id)", "track_creating_job_permit(database_id, job_id, permit)"):
    assert token in constructor, f"startup recovery admission missing {token}"
PY
