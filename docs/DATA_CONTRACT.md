# Benchmarking data contract (reference)

The normative spec for the OCaml benchmarking pipeline: benchmark definition →
run configuration → execution → ingestion → visualization. `README.md` is the
friendly overview; this document is the detail.

**The contract is normative and change-it-first.** When anything about the
pipeline changes — a new runtime, modifier, metric, or comparison — edit
`lib/schema/` (and this doc) *before* any tool, then regenerate the JSON Schema
and vocab. A change then flows through *or fails loudly* — it never silently
misparses (which is how the previous filename-based scheme, and current-bench,
broke). OCaml (`lib/schema/`) is canonical; JSON Schema + a Python vocab are
generated from it.

---

## Why a contract

Run identity used to be carried **entirely by the log filename**
(`bench.0.0.ocaml-gc-pacing.perf_grp1.re-25.md-2.…macro-cpdf.log`), produced by
running-ng and **re-parsed by an independent regex** in every reader — fragile in
exactly the ways that matter:

- two implementations of an implicit schema drift → silent misparse;
- runtime → version/flags was a naming convention (OxCaml/MMTk names broke it);
- the reader hardwired the GC-param list (`s`,`o`,`M`,`m`);
- comparisons lived only in YAML + a notebook, so the data had no notion of them;
- metric shapes were unvalidated raw tool output.

The fix: **self-describing data** with **one shared schema**, so a measurement
says what it is instead of being decoded from its filename.

## Principles

1. **Self-describing data.** A measurement carries its own identity; filenames
   are opaque storage keys, never parsed back.
2. **One schema, one home, versioned.** Defined once in `lib/schema/`, stamped
   with `schema_version`.
3. **Dimensions and metrics are open key/value sets.** Adding a sweep axis or a
   metric never requires a schema migration.
4. **Comparisons are declared data** that travel with the results.
5. **Fail loud, degrade gracefully.** Unknown fields preserved; missing optional
   → null; version mismatch reported, not guessed around.
6. **Legacy knowledge lives on the producer side; the ingestor is contract-only.**
   Exactly one component — the adapter (in running-ng: `contract-adapter/`) —
   knows the legacy on-disk layout, and it runs where the data is produced.
7. **The contract is the only thing a runner builds against** (see
   [Runner conformance](#runner-conformance)).

## The pipeline

```
 Run config (schema_version?) ──▶  running-ng ──┬─ set  → emits CONTRACT natively, self-validates
                                                 └─ null → emits LEGACY ──▶ contract-adapter
                                                          │                  legacy → contract
                                                          └────── CONTRACT ───┘  (+ raw logs, archival)
                                                                     ▼
                                          INGESTOR (ingest/) — contract-only
                                          read → version gate → validate → merge → serve
                                                                     ▼
                                          Visualization (Observable pages, src/)
```

Both the adapter (legacy) and native running-ng emission produce the same
contract artifacts, with identical `config_id`s — they are interchangeable
producers. The ingestor only ever sees contract artifacts.

---

## The contract (artifacts)

Canonical types live in `lib/schema/contract.ml`; each has `to_yojson`,
`of_yojson` (the validator — a record that does not parse is not conformant), and
`_jsonschema` (for schema generation). Fields are **normative** (every runner
must produce/honor) or **advisory** (provenance, prefixed `_`, no consumer may
depend on them).

### Run configuration — the input contract `[input]`
The YAML documenting a run; its grammar **and expansion semantics** are normative
(config-string DSL, sweep cross-product, `includes`/`overrides` merge), so the
same config is portable across runners:
```
runtimes:  { name: {kind, version|commit|executable, options?, repo?} }
suites:    { name: {type, timeout, programs:{p:{path,args,...}}} }
modifiers: { name: {type, ...fields, excludes?} }
benchmarks:{ suite: [program,...] }
configs:   [ "runtime|mod|mod-val|..." ]     # the run set
config_sweep?: { modifier: [value,...] }      # cross-products into configs
comparisons?:  [ ... ]                         # see below
invocations: int
schema_version?    # set => runner emits contract natively; null => legacy + adapter
includes? / overrides?
```

### Benchmark registry entry `[input]` — `Contract.benchmark_entry`
```jsonc
{ "name":"cpdf_scale", "suite":"macro-cpdf-monorepo", "path":"cpdf/…",
  "args":["scale","in.pdf"], "tags":["macro","slow"], "build_model":"switch" }
```

### Config descriptor `[output]` — `Contract.config_descriptor`
Structured replacement for the config string. `config_id` is a **content hash of
the normative fields** (`Registry.canonical_config_id`) — runner-independent, so
two runners produce the same id for the same config and their data is joinable.
```jsonc
{
  "config_id": "cfg_9337278c…",
  "runtime": { "kind":"OCaml", "version":"5.6.0+trunk", "commit":"…", "options":[] },
  "dimensions": { "runtime_events_ring_log2":25, "max_domains":2 },   // OPEN set
  "tools": ["perf","olly"],
  "_runtime_name": "ocaml-trunk-cfb30145",                            // advisory
  "_modifiers": ["perf_grp1","re-25","md-2"]                          // advisory
}
```

### Measurement record `[output]` — `Contract.measurement` (the linchpin)
One per (benchmark × config × invocation). `metrics[]` is an **open list** of
`{name,value,unit,source,layer}` — layer 1 user-visible / 2 GC / 3 hardware.
Emitted per-tool (`measurements/{olly,perf}.ndjson`); the ingestor merges records
sharing `(run_id, config_id, benchmark, invocation)`.
```jsonc
{
  "schema_version": "1.0",
  "run_id": "monolith-2026-05-25-Mon-102618",
  "benchmark": { "name":"cpdf_scale", "suite":"macro-cpdf-monorepo", "tags":["macro"] },
  "config": { "config_id":"cfg_9337278c…" },
  "invocation": 3,
  "metrics": [
    { "name":"wall_time",   "value":13.02,  "unit":"s",     "source":"olly", "layer":1 },
    { "name":"instructions","value":2.09e11,"unit":"count", "source":"perf", "layer":3 }
  ],
  "raw_ref": { "olly":"olly_cpdf_scale.….json#L3" }                   // advisory
}
```

### Run manifest `[output]` — `Contract.manifest`
One per run: structured machine + `tool_versions`, the config descriptors that
ran, the declared comparisons, and advisory `_produced_by`.

### Comparison declaration `[input→output]` — `Contract.comparison`
Selects over the config space (matches configs by their fields), so a sweep — just
config expansion — is compared *along* a dimension rather than by enumerating ids:
- **`inter`** — vary runtime, config fixed (e.g. 5.4.1 vs 5.5.0). `over:"runtime"`, `baseline`+`variants` selectors, `mode: pairwise|cartesian`.
- **`intra`** — one runtime, vary swept dimension(s) → curve/heatmap. `fix`, `over:[dim…]`, optional `baseline_at`.
- **`both`** — for each swept point, compare runtimes.

All resolve at query time against configs that actually ran (partial data
degrades gracefully; a comparison never hard-references a `config_id`). The
dashboard renders `inter` today; `intra`/`both` are stubs to extend in `src/`.

---

## Runner conformance

A **Runner** is any tool that satisfies: **config in → conforming artifacts out**,
and nothing else about it is observable. Python running-ng (native or via the
adapter), an OCaml rewrite, a local run, or a third-party tool are interchangeable
if they conform.

A runner conforms iff it (1) accepts a config and honors its expansion semantics,
(2) emits a manifest + one measurement record per invocation, valid against the
schema with all normative fields populated, (3) computes `config_id` as the
canonical hash so ids are runner-independent, and (4) puts identity in fields,
never in filenames or log prose. *How* metrics are collected, the build
mechanism, and provisioning are out of scope — implementation freedom.

---

## Extending the contract

**Golden rule: change the contract first.** For every change, edit `lib/schema/`
(and regenerate `schema/json/*.schema.json` + `vocab.json`, and running-ng's
`vocab.py`) *before* touching any tool. Ordered by frequency:

### Add a metric (e.g. future olly fragmentation stats)
1. `lib/schema/registry.ml`: add to `metric_catalog` (`("heap_fragmentation",("pct",2,"olly"))`) and the extraction map (`olly_field_map` dotted path → name, or `perf_event_map` event → name).
2. **No `schema_version` bump** — `metrics[]` is open (additive path).
3. Then: nothing else is *required* — adapter/native read the registry, the viz charts by name. Touch the adapter only for non-trivial extraction; running-ng must run the tool.

### Add a sweep dimension / GC parameter
1. `lib/schema/registry.ml`: add to `dimension_of_modifier` (`("newtok",("canonical_dimension","unit"))`).
2. No type change — `dimensions` is open; `config_id` includes it.
3. Then: running-ng defines the modifier + sweeps it; the viz can plot the axis in `intra`/`both`.

### Add a runtime type (new compiler kind/fork)
1. `lib/schema/contract.ml`: add the canonical string to allowed `runtime.kind`. `version`/`options` are already explicit → usually no structural change.
2. Then: running-ng adds a `Runtime` subclass emitting explicit kind/version/options; the adapter adds a name→kind case (legacy). `config_id` stays stable → no reader changes.

### Add a modifier / wrapper (not a measurable axis)
Usually nothing — pure-provenance modifiers surface in advisory `_modifiers`. If it carries a measurable axis, use the sweep-dimension recipe.

### Add a comparison kind or selector field
1. `lib/schema/contract.ml`: extend `comparison` / document the new `kind`. Optional fields need no bump; structural changes do.
2. Then: the viz resolver/renderer handles the new kind.

### A breaking change in an external tool (olly / perf output format)
1. `lib/schema/registry.ml`: update the affected map to the new field layout, and bump the tool's entry in `tool_supported_versions`.
2. Bump `Contract.schema_version` **only if** the change forces different canonical names/units/semantics; otherwise it's absorbed in `registry.ml` and consumers never see it.
3. Then: the runner records tool versions; the ingestor prefix-matches against `tool_supported_versions` and reports an unsupported one.

### Structural / breaking change (rename or remove a field, change a meaning)
1. `lib/schema/contract.ml`: make the change and **bump `schema_version`** (major).
2. Regenerate the JSON Schema + vocab.
3. Update ingestor, viz, running-ng emitter. The validator + version check make non-conformers fail loudly.

### After any contract change
`dune build && dune exec tools/gen_schema.exe -- schema/json && dune exec tools/gen_vocab.exe -- schema/json/vocab.json`, regenerate running-ng's `vocab.py`, then `dune exec test/smoke.exe`.

---

## Versioning and graceful degradation

**Three distinct version concepts:**

| Version | Lives in | Versions what | Bumped when |
|---|---|---|---|
| `schema_version` | every artifact | our canonical shapes/names/units | *we* change the contract |
| `tool_versions` | the run manifest | the actual olly/perf **binaries** (provenance) | recorded every run |
| `tool_supported_versions` | `registry.ml` | the tool versions our maps expect | a tool changes its output |

A breaking olly/perf change is caught by the third: the runner records each tool's
**release** version (olly from the binary it runs — resolved to its owning switch
or git checkout, since olly has no `--version`; perf via `perf --version`), and
the ingestor prefix-matches against `tool_supported_versions`, failing loud on an
unsupported one. olly *also* self-stamps a coarser **output-format** version in its
JSON (`"version": 1` or `2`), checked against `olly_output_version_supported`. A
tool change bumps `schema_version` only if it leaks to canonical names/units —
olly's 1 → 2 did not (it added an `outliers` block), so both are accepted.

- Every artifact carries `schema_version` (semver). A **major** mismatch is
  refused; a newer **minor** is read with unknown fields preserved.
- Missing optional field → treated as absent, never an exception.
- The ingestor validates each record and **quarantines + reports** failures.
- **Additive metrics need no version bump** (open `metrics[]`); a bump is reserved
  for structural changes.

---

## Migration status

`schema_version` is the switch: **null → legacy → adapter**; **set → native
emission**. Both are validated and produce identical `config_id`s.

1. **Done — native emission.** running-ng reads `schema_version` and emits contract
   artifacts natively during a run (`~/running-ng`, `data-contract` branch), in
   pure Python via a vocab generated from `bench-contract`. Verified: native
   `config_id`s and comparisons match the adapter's for the same run.
2. **Legacy path** — the `contract-adapter` converts old/foreign runs after the
   fact (reads sidecars + `runbms.yml` identity), a versioned sunset path.
3. **Eventual** — an OCaml running-ng is just another conforming Runner, validated
   by the same golden fixtures; the adapter retires once nothing legacy remains.

### Validation boundaries
| Boundary | Validate | State |
|---|---|---|
| ① config → running-ng | valid config for its `schema_version` | ○ config validator (addable) |
| ② running-ng → artifacts | producer self-validates before writing | ✓ (adapter + native) |
| ③ artifacts → ingestor | version gate + contract validation + referential integrity | ✓ (`ingest/`) |
| ④ ingestor → dashboard | canonical contract served | ✓ |

---

## How this could become a hosted service

Static-rebuild model (low maintenance, no live backend): a bot triggers a run on
tuned hardware → the runner emits contract artifacts → the controller ingests +
`npm run build` → a static site on nginx / GitHub Pages. Because runs emit
contract artifacts, local and CI runs render through the same pipeline.
