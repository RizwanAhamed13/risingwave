# Full-lifecycle streaming backfill admission

RisingWave limits concurrent streaming-job creation, but background and serverless backfill requests can outlive the RPC that admitted them. Make admission ownership cover the complete catalog creation lifecycle, including meta recovery.

## Required behavior

- Acquire capacity before provisioning or building a streaming job. Foreground, background, serverless-backfill, and subscription creation must use the same configured capacity.
- Returning from a background DDL request after its first barrier must not release capacity. Transfer ownership so it remains held until the catalog reports `Created`, or until cancellation, failure, or drop removes the creating job.
- A transient finish-notifier or recovery error must not release capacity. Re-register or retry until a terminal catalog outcome is observable.
- Before accepting new DDL after meta startup, reconstruct admission ownership for every catalog job still in `Creating`. Recovered jobs may initially exceed the configured limit; in that case, block new work and drain naturally.
- Runtime limit increases must wake blocked work. Runtime decreases below active usage must be drain-only: do not evict active work and do not admit again until usage is below the new limit. A configured value of zero means unlimited.
- Do not leak or double-release ownership on cancellation, failure, drop, waiter cancellation, or recovery.
- Expose deterministic state for observability: configured limit, active ownership, tracked creating jobs, and waiting admissions. Emit useful lifecycle logs for waits, acquisition, recovery, release, and limit changes.

Do not add timing-based admission behavior or weaken existing foreground creation semantics.

## Validation surface

Keep the existing `CreatingStreamingJobPermit` type usable by its module tests with deterministic limit, acquisition, recovery-claim, release, and stats operations. Use `CreatingStreamingJobInfo::take_permit` to transfer a background job ownership and `GlobalStreamManager::track_creating_job_permit` to retain it through terminal catalog observation; these crate-internal hooks are part of this challenge validation surface.
