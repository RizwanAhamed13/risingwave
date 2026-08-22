#!/usr/bin/env bash
set -uo pipefail
mode=""
output_path=""
while (($#)); do
    case "$1" in
        base|new)
            [[ -z "$mode" ]] || { echo "mode specified more than once" >&2; exit 2; }
            mode="$1"; shift ;;
        --output_path)
            shift
            (($#)) || { echo "--output_path requires a value" >&2; exit 2; }
            output_path="$1"; shift ;;
        --output_path=*) output_path="${1#*=}"; shift ;;
        *) echo "usage: ./test.sh [--output_path PATH] {base|new}" >&2; exit 2 ;;
    esac
done
[[ -n "$mode" ]] || { echo "usage: ./test.sh [--output_path PATH] {base|new}" >&2; exit 2; }
[[ -n "$output_path" ]] || output_path="test-results.xml"
mkdir -p "$(dirname "$output_path")"
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT
target_dir="${CARGO_TARGET_DIR:-/tmp/risingwave-admission-${mode}}"
feature_args=()
if [[ "$mode" == "base" ]]; then
    filters=(
        "rpc::ddl_controller::tests::test_validate_specified_parallelism"
        "controller::catalog::test::tests::test_foreground_creating_catalog_lifecycle"
        "controller::catalog::test::tests::test_cancel_creating_job_includes_belonging_streaming_jobs"
    )
else
    feature_args=(--features rw_full_lifecycle_admission_tests)
    filters=("rpc::ddl_controller::tests::test_creation_admission_")
fi
overall=0
for filter in "${filters[@]}"; do
    printf 'running filter: %s\n' "$filter" | tee -a "$log_file"
    CARGO_TARGET_DIR="$target_dir" cargo test --locked -p risingwave_meta --lib "${feature_args[@]}" "$filter" -- --nocapture 2>&1 | tee -a "$log_file"
    status=${PIPESTATUS[0]}
    ((status == 0)) || overall=1
done
python3 - "$mode" "$output_path" "$log_file" <<'PYXML'
import re, sys
import xml.etree.ElementTree as ET
from pathlib import Path
mode, output_path, log_path = sys.argv[1:]
log = Path(log_path).read_text(errors="replace")
base = [
"rpc::ddl_controller::tests::test_validate_specified_parallelism_accepts_within_max",
"rpc::ddl_controller::tests::test_validate_specified_parallelism_rejects_parallelism_over_max",
"rpc::ddl_controller::tests::test_validate_specified_parallelism_rejects_backfill_parallelism_over_max",
"controller::catalog::test::tests::test_foreground_creating_catalog_lifecycle",
"controller::catalog::test::tests::test_cancel_creating_job_includes_belonging_streaming_jobs"]
new = [
"rpc::ddl_controller::tests::test_creation_admission_limit_reduction_is_drain_only",
"rpc::ddl_controller::tests::test_creation_admission_recovery_can_start_over_limit",
"rpc::ddl_controller::tests::test_creation_admission_reports_waiters_and_wakes_on_release",
"rpc::ddl_controller::tests::test_creation_admission_limit_increase_wakes_waiter",
"rpc::ddl_controller::tests::test_creation_admission_cancelled_waiter_is_not_leaked",
"rpc::ddl_controller::tests::test_creation_admission_anonymous_and_job_share_capacity",
"rpc::ddl_controller::tests::test_creation_admission_zero_limit_means_unlimited",
"rpc::ddl_controller::tests::test_creation_admission_background_ownership_is_transferred",
"rpc::ddl_controller::tests::test_creation_admission_tracker_retries_transient_errors",
"rpc::ddl_controller::tests::test_creation_admission_startup_claims_catalog_jobs"]
expected = base if mode == "base" else new
observed = {m.group(1):m.group(2) for m in re.finditer(r"^test (.+?) \.\.\. (ok|FAILED|ignored)$",log,re.MULTILINE)}
summaries = re.findall(
    r"^test result: (ok|FAILED)\. (\d+) passed; (\d+) failed;",
    log,
    re.MULTILINE,
)
expected_summaries = 3 if mode == "base" else 1
complete = (
    len(summaries) == expected_summaries
    and all(status == "ok" and int(failed) == 0 for status, _, failed in summaries)
    and sum(int(passed) for _, passed, _ in summaries) == len(expected)
)
suite=ET.Element("testsuite",{"name":f"risingwave_creation_admission_{mode}","tests":str(len(expected))})
failures=0
for name in expected:
    case=ET.SubElement(suite,"testcase",{"classname":name.rsplit("::",1)[0],"name":name.rsplit("::",1)[-1]})
    if not complete and observed.get(name)!="ok":
        failures+=1
        ET.SubElement(case,"failure",{"message":"test failed or did not execute"}).text=log[-12000:]
suite.set("failures",str(failures)); suite.set("errors","0"); suite.set("skipped","0")
ET.SubElement(suite,"system-out").text=log
ET.ElementTree(suite).write(output_path,encoding="utf-8",xml_declaration=True)
sys.exit(1 if failures else 0)
PYXML
xml_status=$?
((xml_status == 0)) || overall=1
exit "$overall"
