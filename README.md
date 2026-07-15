# ocaml-bench-dashboard

A small pipeline and web dashboard for OCaml compiler/runtime benchmarks. It
turns benchmark runs from [running-ng](https://github.com/udesou/running-ng) into
a browsable performance site — regression comparisons across compiler versions
and GC configurations.

Results flow through a stable **data contract** (self-describing measurement
records + a run manifest), so the runner, the storage, and the charts can evolve
independently. This repo owns the contract (OCaml types in `lib/schema/`), the
**ingestor** that validates it, and the **dashboard** (Observable Framework). The
benchmark runner and the legacy adapter live in `~/running-ng`.

For the full contract spec see [docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md).

---

## Run the dashboard

You need the OCaml toolchain (opam) and Node ≥ 18.

**1. Build the OCaml tools (once):**

```sh
opam switch create ocaml-bench-dashboard ocaml-base-compiler.5.4.1   # or reuse a 5.x switch
eval $(opam env --switch=ocaml-bench-dashboard)
opam install -y dune yojson ppx_deriving_yojson ppx_deriving_jsonschema

dune build
dune exec tools/gen_schema.exe -- schema/json            # generate JSON Schema
dune exec tools/gen_vocab.exe  -- schema/json/vocab.json # generate vocab
mkdir -p bin && cp -f _build/default/ingest/ingest.exe bin/ingest
opam pin add -y -k path bench-contract .                 # so the runner's adapter can depend on it
```

**2. Point it at a benchmark run and start the site:**

```sh
npm install                                              # once
export BENCH_RUN_DIR=~/running-ng/gc-sweep-logs-pr14796/monolith-2026-05-25-Mon-102618
npm run dev            # live preview at http://127.0.0.1:3000/
```

`npm run dev` first turns the run into contract artifacts (`./contract/`) and then
serves the site, reloading as you edit `src/`. For a static build instead:

```sh
npm run build          # -> dist/
python3 -m http.server -d dist 8099   # then open http://127.0.0.1:8099/
```

> **Remote/SSH?** `npm run dev` binds to `127.0.0.1:3000` on the server. In
> VS Code, forward port **3000** (PORTS panel → *Forward a Port*) and open the
> **Local Address** it shows (use `http://`, not `https://`).

### 📂 Show a different benchmark run

Set `BENCH_RUN_DIR` to the run you want and restart:

```sh
export BENCH_RUN_DIR=/path/to/gc-sweep-logs-XXX/monolith-YYYY   # a single run dir
npm run dev        # (restart it — the run is picked up at startup)
```

- Point at the **timestamped run directory** (the one containing the sidecars /
  a `contract/`), **not** the top-level `gc-sweep-logs-*` folder.
- **You never re-run the benchmarks.** Whatever the run is, it's handled
  automatically:
  - a **native** run (already has `contract/`) is used as-is;
  - an **older/legacy** run is converted on the fly by `scripts/adapt.sh` via
    `running adapt` (resolves the YAML anchors in `runbms.yml` for precise
    runtime identity), falling back to the standalone adapter binary.
- One-time prerequisite for legacy runs: build the adapter once —
  `(cd ~/running-ng/contract-adapter && ./build.sh)`.

---

## What you see

Four pages (sidebar nav):

- **Overview (regression)** — one section per comparison declared in the run's
  manifest (e.g. *“5.5.0-rc1 vs 5.4.1”*): a per-benchmark Δ bar chart (green =
  faster, red = regression) + a table. A **metric selector** switches what's
  compared (instructions, wall time, max RSS, GC overhead, …).
- **GC & runtime** — Δ of GC/runtime metrics (overhead, collections, promotion),
  which explain *why* wall time moved.
- **Absolute values** — raw per-benchmark medians per runtime (no baseline).
- **Parameter sweeps** — heatmap of a metric across two swept GC parameters
  (e.g. `minor_heap` × `space_overhead`), for sweep runs.

The charts are [Observable Plot](https://observablehq.com/plot/) calls in `src/`
(shared helpers in `src/components/bench.js`) — edit those to change or add views.

---

## How it fits together

```
running-ng run ──▶ contract artifacts ──▶ ingestor ──▶ dashboard
 (native, or           manifest.json      (validate,     (Observable
  legacy → adapter)     measurements/       merge)         Framework)
```

- **Contract** — `lib/schema/` (OCaml types), published as the opam package
  `bench-contract`; JSON Schema + a Python vocab are generated from it.
- **Ingestor** — `ingest/ingest.ml`: reads a contract directory, version-gates
  and validates every record, checks referential integrity, and merges per-tool
  measurements.
- **Dashboard** — `src/`: Observable Framework pages fed by `bin/ingest`.

## Repository layout

```
lib/schema/        the data contract: types (contract.ml) + registries (registry.ml)
tools/             gen_schema.ml / gen_vocab.ml  → schema/json/{*.schema.json, vocab.json}
ingest/            contract-only ingestor (validate + merge)
src/               the dashboard: index.md (overview), gc.md, absolute.md, sweep.md
src/components/    bench.js — shared data + chart helpers used by the pages
scripts/adapt.sh   producer step: native contract as-is, else `running adapt` → ./contract
test/smoke.ml      round-trip / validation sanity check
docs/              DATA_CONTRACT.md — the full spec
```

## Developing

Change the contract **first**: edit `lib/schema/`, regenerate the JSON Schema and
vocab, then update the ingestor and charts. See
[docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md) (“Extending the contract”) for the
one-file-to-touch recipe per kind of change, and `CLAUDE.md` for contributor
conventions.
