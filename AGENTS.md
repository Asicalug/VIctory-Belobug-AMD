# Agent handoff: RX 9070 XT native-1440p RT

## Current objective and acceptance

Work toward repeatable, stable **30 fps or better at native 2560×1440** with the
title's ray-traced indirect lighting. Do not reduce texture size/mips, render
scale, native input resolution, RT, or other visual settings to get there.
Preserve shader-write/title-write ordering, guarded-view behavior, crash-page
handling, landing semantics, and no-lost-write coverage.

Use bounded, repeatable opening/heavy-scene/transition benchmarks. Review, test,
commit and push validated work. Open a PR to `Belobug/VIctory-Belobug-AMD`
**only after acceptance evidence is met**, then address available review
comments. No PR is justified now: heavy scenes remain well above 33.3 ms/frame.

Earlier tasks t1–t21 are complete. Ordered parallel card-copy merging is now
retained and validated; native heavy-scene acceptance remains unmet.

## Exact handoff state

- Repository: `C:\Users\FlowUp\VIctory-Belobug-AMD`.
- Always set this as the tool working directory. The default tool directory can
  be the unrelated `C:\Users\FlowUp\VIctory-7900XTX`; do not modify that tree.
- Branch: `amd-rx9070-native30`, tracking `fork/amd-rx9070-native30`.
- Remotes:
  - `origin`: `https://github.com/Belobug/VIctory-Belobug-AMD.git`.
  - `fork`: `https://github.com/Asicalug/VIctory-Belobug-AMD.git`.
- Integration branch: `origin/a-publier` (the original repository's default),
  not the older, divergent `origin/main`.
- Last pull of `origin/a-publier`: `Already up to date`; all its commits were
  already integrated.
- Latest retained code baseline: `17ed48c` (synchronous direct uploads).
  All committed work through `17ed48c` is pushed to the fork.
- The t21 source experiment has been reverted; no t21 source modifications
  remain in `crates/victory-gpu/src/land.rs` or `land/tests.rs`.
- The rejection and native A/B evidence are recorded in `docs/rx-9070-xt.md`.
- No `victory.exe` or `game_scarlett_master.exe` benchmark process remained after
  the last intended timeout.
- Latest default-release acceptance log:
  `C:\Users\FlowUp\AppData\Local\victory\logs\play-20261127-222102-12860.log`.
- Latest diagnostics refresh profile:
  `C:\Users\FlowUp\AppData\Local\victory\logs\play-20261127-223906-8840.log`;
  latest rejected sparse-planning A/B: `play-20261127-225604-23816.log`.
  The direct-upload A/B remains `play-20261127-221132-2864.log`, its preparation
  profile is `play-20261127-220352-14284.log`, the ordered copy-back A/B remains
  `play-20261127-214230-9640.log`, and the memory census remains
  `play-20261127-210714-12456.log`.
- The default-release run held 30 fps in the opening/menu, but heavy 3D did not
  meet acceptance. Final samples were 7.4/7.2 fps at 135.6/138.4 ms with about
  5,000 draws; a heavy transition reached 1,114.1 ms. No PR is justified.
- It had no panic, device removal, out-of-memory report or fatal runtime error.
  Launcher exit `-1` was the intended benchmark timeout killing the title, not
  a title crash. Explicit cleanup confirmed zero benchmark processes.
- Final heavy costs were 42.5 ms preparing (22.1 ms copies), 59.8 ms on the GPU,
  and 32.5 ms copying back. Earlier baseline `204114-1604` instead had a
  61.4 ms preparation / 49.2 ms copy-back representative sample; scenes differ,
  so do not claim a whole-frame improvement from those two runs. The
  109,104-shape / 3,710.5-MiB cumulative list-making figures belong to earlier
  diagnostics, principally `201726-9068`, not the release logs.
- The heap-slot profile and rejected placed-shape hash-table experiment are
  documented in `docs/rx-9070-xt.md`; their temporary source changes were
  reverted. The memory-usage investigation is complete and documented below.

## Completed t21 decision

The 512 KiB landing-job target was **not retained**. The first native A/B's
whole-frame advantage did not repeat, and neither fetched-merge nor guard
opening/noting costs showed a repeatable local reduction. The two bounded runs
and their paired heavy-phase measurements are recorded in
`docs/rx-9070-xt.md`, under "Rejected larger landing jobs". Only the two t21
source diffs were reverted; the default remains 256 KiB and no experiment switch
or temporary test remains.

Memory ownership and lifetime have now been quantified as described below;
no permanent multi-GiB leak or safe early-free rule was validated. Next, choose
one measured 3D hotspot. The preceding heap profile left roughly
11,000–17,000 buffer copies per heavy frame after table-owned slots exited;
focus on measured mirror/copy costs, not cheap early exits. The default run also
spent 49.2 ms copying back in its representative heavy frame. Keep whole-frame
comparisons matched by scene and draw count. Relay landing remains another
large, overlapping critical path.

## Copy-back merge decision

Ordered parallel merging of synchronous card copy-back is **retained and on by
default**. Before the fetch, `land::ordered` sorts by 64 KiB title block,
coalesces overlapping/touching pieces of one copy, and preserves cross-copy
order within a block. `land::jobs`/`land::each` then keep aliases of one title
block in one ordered job. `VICTORY_WIDE_MERGE=0` selects serial merging.

Diagnostics A/B `214230-9640` roughly halved local merge cost: representative
115–120 MiB batches fell from 35–40 ms to 15–17 ms, and later 85–105 MiB batches
from 27–29 ms to 14–16 ms. Heavy phases 12→13 (serial→parallel) improved from
268.7 to 182.3 ms mean and 348.4 to 201.2 ms p90 at 4,380→4,442 draws. This is
an incremental optimization, not stable-30 evidence. The default release check
`215334-22336` retained every native-quality setting and still reached only
5–6.6 fps in heavy 3D with a 940.4 ms transition. Both runs were bounded,
used no screenshots, and were explicitly cleaned up to zero benchmark processes.
The complete serial GPU suite passed 399 tests with 35 ignored; diagnostics
check and both builds passed. Full evidence is in `docs/rx-9070-xt.md`.

## Synchronous direct-upload decision

Synchronous card uploads now read dirty ranges directly from their existing CPU
staging sides by default. The submission lock is held until every list has been
waited for, so a later submission cannot refresh those bytes first. Late/relay
submissions still require `send::take()` snapshots. Set
`VICTORY_SYNC_SEND_DIRECT=0` to restore synchronous snapshots for diagnosis.

Preparation profile `220352-14284` found 15.12 ms in representative card-copy
preparation, including 11.92 ms taking bytes, 1.62 ms gathering and 1.44 ms
recording. Other late costs remained about 29 ms in list steps (22–23 ms
refreshes), 6.8 ms snapshots and 63–65 ms on the GPU. In direct-upload A/B
`221132-2864`, the closest heavy phases 12→13 improved from 180.3 to 152.8 ms
mean, 176.1 to 153.3 ms median and 199.3 to 162.8 ms p90 at 5,071→4,954 draws.
Local preparation fell from 15.12 to 2.98 ms and taking bytes to zero. Phase 14
returned to snapshots at 165.0 ms mean / 4,965 draws. Phases 8→9 did not improve
(205.3→208.2 ms at 3,252→3,172 draws), so do not claim a universal multiplier.

Default release `222102-12860` retained every native-quality setting and ended
at 7.4/7.2 fps, 135.6/138.4 ms around 5,000 draws, with a 1,114.1 ms transition.
Acceptance remains unmet. The runs used no screenshots and were explicitly
cleaned up to zero processes. Diagnostics check, both builds and all 399 serial
GPU library tests passed, with 35 ignored. Full evidence is in
`docs/rx-9070-xt.md`.

## Refresh investigation result

The corrected `223906-8840` profile found roughly 9–20 ms worker-summed no-op
checking, 58–72 ms worker-summed actual updates and 20–24 ms wall-clock refresh
time in representative heavy scenes. Only about 190 precheck exits were in-place
buffers, so a placed-buffer-only prefilter is not a useful target.

A range-covered sparse stale-run planner was tested and **not retained**. Its
2,000 randomized full-scan equivalence cases and 48 serial watch tests passed,
but native A/B `225604-23816` showed written entries approximately equal to all
covered pages (for example 22,358 of 22,358). Local planning differences were
inconsistent and at most 0.131 ms/frame in the documented representative pairs;
whole-frame changes had large scene/draw differences. The source experiment and
counters were removed, leaving `host.rs` and `shadow.rs` at `17ed48c`; the
rejected diff is archived only under ignored `target/`. Full numbers are in
`docs/rx-9070-xt.md`. No screenshots were taken and explicit cleanup confirmed
zero processes. Stable-30 acceptance remains unmet and no PR is justified.

## Memory investigation result

- Bounded native-quality runs `205058-8096` (diagnostics address map),
  `210009-8636` (ordinary release), and `210714-12456` (resource census) used no
  screenshots and were cleaned up afterward. Release private bytes reached about
  28.3 GB, then fell/fluctuated rather than growing monotonically; working set
  also fell late in the run. This validates extreme ownership, not a monotonic
  leak over the bounded window.
- The final census has 45,472 live book entries / 22,721 MiB including overlaps,
  62,798 gone entries, and 2,003 resources awaiting retirement. Big owners are
  title memory (5,740 MiB), title buffers (1,897 MiB), texture-pool blocks
  (5,888 MiB), placed textures (1,105 MiB), and runtime buffers (2,302 MiB).
  Pool blocks contain placed textures, so these are not unique physical-memory
  amounts. Carded mirrors can own both CPU staging and GPU-side copies.
- The 84,765 placed descriptor shapes in the diagnostics map run account for only
  about 32 MiB of descriptor/view storage. Cumulative list-making growth is not
  live storage. Retirement backlog reaches 56,605 objects and later falls to
  2,003. No specific permanent multi-GiB leak or safe early-free rule was
  validated. The resource-book census and `retired_waiting` are diagnostics-only
  census aids; do not trade away fences, live title mirrors, shader-write ordering,
  partial ranges, or guarded views to lower these totals.

## How the repository works

This is a Rust 2024 Windows/D3D12 compatibility layer for a user-supplied Xbox
Series title. It ports/patches renderer behavior where possible rather than
emulating every console operation. Rust 1.88 is the workspace minimum; the
repository pins the actual toolchain. Game files/assets are not in this repo.

### Workspace map

- `apps/victory`: `victory` CLI (`run`, shader translation, `warm`, diagnostics).
- `crates/victory-loader`, `victory-pe`: PE/image loading and title mapping.
- `crates/victory-hle`: high-level Xbox/runtime services, including lifecycle,
  input, COM and module behavior.
- `crates/victory-gpu`: D3D12 runtime, descriptor heaps, memory tracking,
  submission preparation, uploads, residency, copy-back and landing.
- `crates/victory-shader`, `victory-pipeline`: shader translation and pipeline
  creation/cache/warm-up support.
- `crates/victory-formats`, `victory-core`, `victory-game`: shared formats,
  core utilities and game-facing support.
- `scripts/play.ps1`: supported launcher and bounded benchmark harness.
- `docs/rx-9070-xt.md`: detailed native-RT settings, measurements, validation,
  and rejected experiments. Keep it updated with performance decisions.

### Frame/data flow

1. Loader/HLE services run the title and intercept its renderer/runtime calls.
2. Thin-list recording translates title command-list calls on worker threads.
3. `draw.rs` and `host.rs` prepare submissions and descriptor tables.
4. Descriptor code mirrors title views into host heaps. The heap-view pass also
   prepares buffers selected by computed shader indices.
5. Most title buffers cannot simply be read by the host GPU. `shadow.rs` keeps
   host copies, often with a CPU staging side plus a card-local side. Dirty
   ranges are refreshed and uploaded before draws.
6. `watch.rs` uses write watching and read-only guards to find title writes.
   Its journal tracks asking/write numbers; landing notes must remain visible
   to later refreshes. Watch pages are 64 KiB; kernel pages are 4 KiB.
7. Card-local copies are hashed/compared after submissions. Changed pieces are
   fetched and merged by `land.rs`/`safecopy.rs` on several workers.
8. The merge stores only shader-changed dwords without overwriting newer title
   bytes. `land.rs` orders pieces by 64 KiB title block, groups them into jobs,
   writes beside guards where possible, then flushes watch notes.
9. Relay completion updates title memory before read-backs/fence signals let the
   title continue. `residency.rs` and texture queues manage VRAM/RAM pressure.

Useful invariants:

- Pieces of one title 64 KiB block stay in one landing job and in input order.
- A landing completes before the title is told its flights completed.
- A refresh must observe both ordinary title writes and shader-landing notes.
- A copy watermark update excludes readers; unchanged checks may read shared.
- Only declared/known ranges are refreshed where the implementation documents
  that shortcut; do not broaden stale-data shortcuts for performance.
- Partial pages/ranges and guarded views are correctness-critical, not optional
  fast-path special cases.

### Builds and profiles

Workspace release uses thin LTO and one codegen unit. `diag` inherits release
optimization but disables LTO, uses 16 codegen units, and enables separate build
output so it does not evict plain release artifacts.

```bash
cargo build --locked --release -p victory
cargo build --locked --profile diag -p victory --features diagnostics
cargo check --locked -p victory-gpu --features diagnostics
```

`-Build diag` in the launcher requests light DRED. Run the launcher normally,
not elevated, so the driver uses the expected shader cache.

### Tests and formatting

GPU/watch tests share global state. Run them serially:

```bash
cargo test --locked -p victory-gpu --lib -- --test-threads=1
cargo test --locked -p victory-gpu refresh_tests -- --test-threads=1
cargo test --locked -p victory-gpu watch::port7_tests -- --test-threads=1
cargo test --locked -p victory-gpu land::tests -- --test-threads=1
```

Goal verification command:

```bash
git diff --check && cargo test --locked -p victory-gpu pipeline::known::tests::crash_records_apply_only_to_their_shader_and_driver_fingerprint && cargo test --locked -p victory-gpu residency::tests
```

Do **not** run `cargo fmt --all`: the current toolchain reformatted about 142
otherwise untouched files earlier. Keep diffs scoped, format touched code
carefully, and use `git diff --check`.

Copy-back and synchronous direct-upload validation: diagnostics check and both
builds passed; the complete serial GPU library suite passed 399 tests with 35
ignored. Existing randomized landing-order coverage checks byte coverage,
cross-copy block order and job boundaries. `git diff --check` is clean.
Memory-census validation had the same serial-suite result and a passing
diagnostics build.

Last committed t20 validation: 399 serial GPU library tests passed, 35 ignored;
focused crash-record and four residency tests passed. Earlier upstream
integration also passed HLE/app suites; see `docs/rx-9070-xt.md` for exact
counts. Default parallel test order has exposed pre-existing shared-state
failures before; only serial results are claimed here.

## Native RX 9070 XT benchmark contract

Test machine: RX 9070 XT, Ryzen 7 9700X, 32 GB RAM, AMD driver
`32.0.32029.2010`.

The `-Rx9070` launcher preset selects:

- Native `VICTORY_OUTPUT=2560x1440`, window cap 2560×1440.
- `VICTORY_RENDER_SCALE=1.0`, title upscaler setting 6, title BVH builder on.
- `VICTORY_TEXTURE_MAX=0`, including under memory pressure. Do not override it.
- Shader optimization mask `59` (REUSE off) and pipeline skip
  `f16876929fa64f9f`. The skip works around an AMD compiler crash and can affect
  skinned animation velocity; do not silently remove or broaden it.
- Residency/memory limits and 256 KiB host-window tracking.
- Normal `VICTORY_LATE_WAIT=0` for synchronized in-place RT arenas.

`-Performance` enables renderer ports 1, 2, 5, 6 and 7 and a 33.333 ms frame
interval. Experiments commonly override `VICTORY_LATE_WAIT=3` and
`VICTORY_CARD_BUFFERS_MIN_MB=1`; these are experiment settings, not silent
changes to the normal preset.

Game executable used by existing logs:

`C:\Users\FlowUp\Downloads\GTA6\game_scarlett_master.exe`

Logs are under `C:\Users\FlowUp\AppData\Local\victory\logs`. The launcher records
its evidence settings at the top of each log. With `-BenchmarkSeconds`, timeout
includes loading and forcibly reaps the title; expect launcher status `-1`.

In-process A/B syntax is `VICTORY_AB=12,<switch>`. Phase 0 is off, phase 1 on,
then phases alternate. Summaries report frames, mean/median/p90 frame time and
draws/frame. Compare local costs and draw counts as well as whole-frame time;
scene/streaming changes frequently confound naive cross-phase or cross-run
comparisons.

## All branch modifications through `128cf88`

The branch is 16 commits ahead of `origin/a-publier` at this handoff baseline.
This table lists every branch commit, including merge/documentation commits.

| Commit | Modification |
| --- | --- |
| `96eccc3` | Scope compiler-crash records and shader skips by translation/driver fingerprint; apply skips during early and normal pipeline creation; preserve legacy record compatibility and warm-up handling. |
| `c9c9bd9` | Open synchronized RT arenas in place instead of copying them, with synchronous submission required for safety. |
| `1e6f01e` | Protect upload headroom and residency behavior on smaller-RAM PCs. |
| `f55cdd8` | Use borderless fullscreen and monitor-aware window placement; associated host/HLE lifecycle integration. |
| `5293266` | Allow scripted input in release benchmarks (bounded `VICTORY_KEYS`). |
| `2a35a38` | Add bounded native RX 9070 benchmark launcher options, preset/evidence logging and `docs/rx-9070-xt.md`. |
| `278a482` | Merge `origin/a-publier` at `4eb6cfd` into the RX branch and resolve integration conflicts. |
| `06fdea2` | Document upstream integration validation. |
| `efbf23a` | Unroll safe landing merge to two 32-byte blocks while keeping both iterations inside fault labels; add measurements. |
| `cb5d4fb` | Coalesce nearby card-upload dirty ranges, including bounded gaps, with matching relay bookkeeping. |
| `d5aa51d` | Instrument card-copy preparation: gathering, byte taking and upload-list recording costs. |
| `a2bcf2a` | Find card-refresh changes directly by dword rather than scalar widening; retain the old route for diagnosis. |
| `64ef7b5` | Avoid one-piece refresh-journal piece-list allocation with a direct one-shard walk and randomized coverage. |
| `c62b7d4` | Document rejected refresh/cache follow-ups and correct benchmark units to milliseconds. |
| `4229146` | Combine per-shadow page/range copy watermarks under one `RwLock`; shared unchanged checks, exclusive updates, diagnostic exclusive-read A/B. |
| `128cf88` | Document shared-watermark native A/B and validation; no FPS improvement claimed. |

Net committed changes relative to `origin/a-publier` touch 15 files: `README.md`,
GPU `draw.rs`, `host.rs`, pipeline files, `residency.rs`, `safecopy.rs`,
`shadow.rs`, `watch.rs`, HLE lifecycle/input files and manifest,
`docs/rx-9070-xt.md`, and `scripts/play.ps1`. The merge also brought upstream
history; do not treat every file in individual commit name lists as a net diff
against the final upstream base.

The rejected t21 experiment left `land.rs` and `land/tests.rs` unchanged.

## Measured but rejected or unproven work — do not retry blindly

- Shader mask 63/REUSE did not establish a win over mandatory mask 59; shader
  cost varied heavily with scene. Keep mask 59.
- Fusing ordinary card-refresh comparison with CPU-held updates passed
  equivalence tests but not whole-frame A/B; removed.
- Eight view-worker threads did not reduce the heap-slot walk versus four;
  rejected.
- An exact-byte AVX2 changed-run encoder had inconclusive whole-frame A/B and
  was not retained.
- Combining remaining submission ranges with refresh observation did not
  materially reduce query counts.
- Page-atomic copy-back publication did not improve its microbenchmark.
- Dirty-byte recording batched across refresh pages was scene-confounded and
  had limited locking benefit; not promoted.
- A globally retired no-change refresh cache passed focused tests after landing
  invalidation fixes but had **zero native hits**; fully removed.
- Shared copy-watermark locking is retained as a smaller lock protocol, but its
  A/B did not establish an FPS win. Do not cite it as such.
- Range-covered sparse stale planning was not sparse in native heavy scenes:
  written entries approximately equaled scanned pages, and local differences
  were inconsistent and at most 0.131 ms/frame in the documented pairs. It was
  removed after A/B `225604-23816`; do not retry without a genuinely sparse
  profile. See `docs/rx-9070-xt.md`.
- t21 larger landing jobs did not provide repeatable local or whole-frame
  benefit across two native A/B runs; the experiment was removed. See
  `docs/rx-9070-xt.md` for the paired measurements.
- A hash index for placed-view shapes passed descriptor tests but did not
  reproduce its apparent local or whole-frame benefit in a second native run;
  it was removed. Do not cite the first, lighter-scene candidate as a win.

## General optimization and benchmark discipline

- Keep screenshots to the minimum needed for visual correctness evidence. After
  every screenshot, benchmark, or other runtime check, run the relevant cleanup
  and confirm that no title, benchmark, screenshot, or viewer process remains.
- Profile before optimizing: define measured hotspots and target those with
  focused, bounded experiments. Do not try unprofiled changes or retry failed
  experiments relentlessly; stop when the evidence rejects the hypothesis and
  require new profiling evidence before revisiting it.

## Git/PR discipline

- Inspect `git status --short --branch` before edits and before cleanup.
- Never discard pre-existing or uncommitted work with broad restore commands.
- Stage only intended files, review `git diff --check` and the final diff, run
  focused plus serial tests, commit, and push `fork/amd-rx9070-native30`.
- Keep rejected experiments documented rather than repeatedly retesting them.
- No pull request until repeatable native-1440p RT heavy scenes and transitions
  demonstrate stable 30 fps without quality reductions.
