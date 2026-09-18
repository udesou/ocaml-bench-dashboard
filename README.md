# ocaml-bench-dashboard

A small pipeline and web dashboard for OCaml compiler/runtime benchmarks. It
turns benchmark runs from [running-ng](https://github.com/udesou/running-ng) into
a browsable performance site: regression comparisons across compiler versions and
GC configurations.

Results flow through a stable **data contract** (self-describing measurement
records plus a run manifest), so the runner, the storage and the charts can evolve
independently. This repo owns the contract (OCaml types in `lib/schema/`), the
**ingestor** that validates it, and the **dashboard** (Observable Framework). The
benchmark runner and the legacy adapter live in `~/running-ng`.

The full contract spec is [docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md).

## Run the dashboard

You need the OCaml toolchain (opam) and Node 18+.

**1. Build the OCaml tools (once):** use a dedicated switch on the `default` opam
repo only, and keep the `ppx_deriving_jsonschema` bound: 0.0.8 renames the runtime
functions the deriver emits and silently rewrites every generated schema. See
[CLAUDE.md](CLAUDE.md).

```sh
opam switch create ocaml-bench-dashboard ocaml-base-compiler.5.4.1
eval $(opam env --switch=ocaml-bench-dashboard)
opam install -y dune yojson yaml ppx_deriving_yojson 'ppx_deriving_jsonschema<0.0.8'

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

> **Remote/SSH?** `npm run dev` binds to `127.0.0.1:3000` on the server. In VS
> Code, forward port **3000** (PORTS panel, *Forward a Port*) and open the **Local
> Address** it shows (use `http://`, not `https://`).

### Show a different benchmark run

Set `BENCH_RUN_DIR` to the run you want and restart; the run is picked up at
startup.

```sh
export BENCH_RUN_DIR=/path/to/gc-sweep-logs-XXX/monolith-YYYY   # a single run dir
npm run dev
```

Point at the **timestamped run directory** (the one containing the sidecars or a
`contract/`), not the top-level `gc-sweep-logs-*` folder. You never re-run the
benchmarks: a **native** run (one that already has `contract/`) is used as-is, and
an **older/legacy** run is converted on the fly by `scripts/adapt.sh`. Legacy runs
need the adapter built once:
`(cd ~/running-ng/contract-adapter && ./build.sh)`.

## Share the dashboard

`npm run build` produces a **fully static, self-contained site** in `dist/`: the
chosen run's data is baked into `dist/_file/data/`, and viewing it needs no OCaml,
Node or ingestor, just an HTTP server. (It cannot be opened as `file://`, since
the browser blocks the module and JSON fetches.)

The easiest way to hand it to someone is a small Docker image that serves `dist/`
with nginx:

```sh
export BENCH_RUN_DIR=~/running-ng/<a-run>
sh scripts/package-image.sh                 # builds dist/ + an image tagged by run name
docker run --rm -p 8080:80 ocaml-bench-dashboard:<run>   # open http://localhost:8080
```

Which run the image shows is fixed at build time by `BENCH_RUN_DIR`; rebuild with
a new tag to share a different experiment. To get it to someone else, either push
it to a registry (GHCR, since the repo is on GitHub) or ship a tarball with
`docker save ... | gzip` and let them `docker load` it.

## What you see

Five pages (sidebar nav):

- **Overview (regression)**: one section per comparison declared in the run's
  manifest, as a per-benchmark delta bar chart (green = faster, red = regression)
  plus a table. A metric selector switches what is compared (instructions, wall
  time, max RSS, GC overhead, ...).
- **Absolute values**: raw per-benchmark medians per runtime, no baseline.
- **Parameter sweeps**: heatmap of a metric across two swept GC parameters
  (`minor_heap` by `space_overhead`, say), for sweep runs.
- **Sweep curves**: one metric's response to one swept parameter, a line per
  runtime, optionally faceted by a second parameter.
- **Space x time tradeoff**: a space metric against a time metric, one point per
  configuration, with each runtime's **Pareto frontier**; plus a cost/benefit
  quadrant of delta-space vs delta-time per parameter point. Parameters can be
  traced, faceted, pinned or left open, and a `★ all benchmarks` mode aggregates
  the suite (per-benchmark normalized geomean over a balanced benchmark set).

The charts are [Observable Plot](https://observablehq.com/plot/) calls in `src/`
(shared helpers in `src/components/bench.js`); edit those to change or add views.

## How it fits together

```
running-ng run ──▶ contract artifacts ──▶ ingestor ──▶ dashboard
 (native, or           manifest.json      (validate,     (Observable
  legacy → adapter)     measurements/       merge)         Framework)
```

- **Contract**: `lib/schema/` (OCaml types), published as the opam package
  `bench-contract`; JSON Schema and a Python vocab are generated from it.
- **Ingestor**: `ingest/ingest.ml` reads a contract directory, version-gates and
  validates every record, checks referential integrity, and merges per-tool
  measurements.
- **Dashboard**: `src/`, Observable Framework pages fed by `bin/ingest`.

## Repository layout

```
lib/schema/        the data contract: types (contract.ml) + registries (registry.ml)
tools/             gen_schema.ml / gen_vocab.ml  → schema/json/{*.schema.json, vocab.json}
ingest/            contract-only ingestor (validate + merge)
src/               the dashboard: index.md (overview), absolute.md, sweep.md,
                   curves.md, tradeoff.md
src/components/    bench.js: shared data + chart helpers used by the pages
scripts/adapt.sh   producer step: native contract as-is, else `running adapt` → ./contract
scripts/package-image.sh   build dist/ and wrap it in an nginx image
test/smoke.ml      round-trip / validation sanity check
docs/              DATA_CONTRACT.md, the full spec
```

## Developing

Change the contract **first**: edit `lib/schema/`, regenerate the JSON Schema and
vocab, then update the ingestor and charts. See
[docs/DATA_CONTRACT.md](docs/DATA_CONTRACT.md) ("Extending the contract") for the
one-file-to-touch recipe per kind of change, and [CLAUDE.md](CLAUDE.md) for
contributor conventions and the operational detail.
