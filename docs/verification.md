# Verification

Checks observed on 17 November 2026 with Luau 0.747, Rojo 7.7.0 and Windows Studio 0.747.0.7471481.

## Passed portable checks

`tests/run.luau`: **13 tests passed**. The updated `src/Core.luau` also passed `luau-analyze`, including the stable-order regression fix.

Coverage includes chronological capacity eviction, independent entity budgets, age filtering of idle entities, immutable copied data, backward-time rejection without mutation, binary-search scrubbing, state filtering, clearing/reusing IDs, finite numeric validation, dense/path-size validation, import schema/chronology limits, failed-record atomicity and stable order for equal-time events.

An independent regression reproduced same-time decisions returning an earlier state after sorting. The stable tie-order fix was rechecked using two interleaved entities and 2–30 equal-time decisions per entity; each returned the latest recorded state. Runtime review also checked dense bounded path validation before copying and rejection of unparented models before tracking.

All runtime, plugin, example and test Luau files compiled locally. Rojo 7.7.0 built `dist/NPCRecorder.rbxm`, `dist/NPCRecorderStudio.rbxm` and `dist/NPCRecorderDemo.rbxlx`. The pinned GitHub workflow runs these checks; a hosted CI run has not yet been observed.

## Studio integration

`tests/studio.luau` passed against the actual runtime and inspector in a real Edit-mode plugin widget. It verified private ServerStorage publication; model-destruction untracking while retaining value history; recorder cleanup and restart rejection after destruction; unparented tracking and dictionary-path rejection; state-filter gaps; navigation through equal-time and sub-100-microsecond decisions; the visible endpoint cursor offset; and failed-import preservation of the previous snapshot.

The live guard example produced 234 sampled/decision events by 33 seconds, including Unspecified, Patrol, Chase and Search, with `LastError` nil. These came from its actual moving scene and raycast-driven state changes. Edit mode reported both IsClient and IsServer true; the corrected explicit Edit/server gating was verified to enable recording there.

Play Server publication, running-client/production inert behavior, actual clipboard transfer across stopping Play, publication-size failure UI and long-duration memory behavior have not yet been exercised by these checks. The pure core's immutability was tested separately from the native integration.

The implementation does not claim exhaustive engine compatibility, automatic intent inference, complete simulation replay, or measured production performance.
