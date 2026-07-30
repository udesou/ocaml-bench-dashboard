# CLAUDE.md — working notes for agents & contributors on `ocaml-bench-dashboard`

Auto-loaded context for Claude Code (and a quick orientation for humans). Keep it
short and current. `README.md` is the human overview; the authoritative spec is
`docs/DATA_CONTRACT.md`.

## What this is

- The **data contract** for the OCaml benchmarking pipeline + its OCaml reference
  implementation of the consumer end. Producers (running-ng: the legacy adapter,
  and native emission) live in the sibling `~/running-ng` repo; this repo owns the
  **contract**, the **ingestor**, and the **dashboard**.
- Flow: `runbms` → (native, or legacy → `contract-adapter`) → **contract artifacts**
  (`manifest.json` + `measurements/{olly,perf}.ndjson`) → **ingestor** (validate +
  merge) → **Observable Framework dashboard**.
- OCaml is the single source of truth for the contract; JSON Schema + a Python
  vocab module are *generated* from it.

## Hard rules (do not violate)

- **No "Claude"/Anthropic/Co-Authored-By: Claude in commit messages.**
- **Commit only when asked.** Nothing here is committed yet by default.
- **Contract-first.** Any pipeline change (new metric, dimension, runtime kind,
  comparison, or structural field) starts by editing `lib/schema/` and the
  contract spec, *before* any producer/consumer — see docs/DATA_CONTRACT.md
  "Extending the contract".
  Then regenerate: `dune exec tools/gen_schema.exe -- schema/json` **and**
  `dune exec tools/gen_vocab.exe -- schema/json/vocab.json`, and regenerate
  running-ng's Python vocab (`~/running-ng/contract-adapter/gen_contract_py.py`).
- **OCaml `lib/schema` is canonical.** JSON Schema (`schema/json/*.schema.json`)
  and `vocab.json` are generated artifacts — never hand-edit them.
- **Don't commit generated/build output**: `/_build/`, `/node_modules/`, `/dist/`,
  `/bin/`, `/contract/`, `src/.observablehq/cache/` (all gitignored).
- **`config_id` is a delimiter-joined canonical string, not JSON** (registry.ml),
  so OCaml and Python reproduce it bit-for-bit. Changing the recipe breaks joins
  across producers — bump it deliberately and regenerate `vocab.json` + `vocab.py`.

## Where things live (read first)

- `lib/schema/contract.ml` — canonical types + `to/of_yojson` (of_yojson = the
  validator) + `_jsonschema`. Packaged as opam lib **`bench-contract`**.
- `lib/schema/registry.ml` — metric catalog, olly/perf field maps,
  modifier→dimension map, `canonical_config_id`, tool-version support.
- `tools/gen_schema.ml`, `tools/gen_vocab.ml` — emit `schema/json/*.schema.json`
  and `schema/json/vocab.json`.
- `ingest/ingest.ml` — contract-only ingestor: glob `measurements/**/*.ndjson`,
  version-gate + validate each record, referential-integrity check (config_id ∈
  manifest), merge partials by `(run_id, config_id, benchmark, invocation)`.
- `src/index.md` — the dashboard page; consumes the manifest's declared
  `comparisons` (inter rendered; intra/both are stubs to extend).
- `src/data/*.json.sh` — Framework data loaders (run `bin/ingest` on `./contract`).
- `scripts/adapt.sh` — demo producer step: invokes the **running-ng adapter**
  (`$BENCH_ADAPTER`) → `./contract` (npm pre-hook).
- `test/smoke.ml` — round-trip / validation sanity check.
- The **adapter** (legacy→contract) and the **Python emitter/generator** live in
  `~/running-ng/contract-adapter/` and `~/running-ng/src/running/contract/`.

## Build / run

- Dedicated opam switch `ocaml-bench-dashboard` (default repo only — **no OxCaml
  overlay**; see gotchas). Recreate it with:
  ```sh
  opam switch create ocaml-bench-dashboard ocaml-base-compiler.5.4.1
  opam install --switch=ocaml-bench-dashboard dune yojson yaml \
    ppx_deriving_yojson 'ppx_deriving_jsonschema<0.0.8'
  ```
  The version bound is not optional — see gotchas. `yaml` is for the running-ng
  adapter, which builds against this switch.
- `dune build` → then `cp _build/default/ingest/ingest.exe bin/ingest`.
- `dune exec tools/gen_schema.exe -- schema/json` / `gen_vocab.exe` after any
  `lib/schema` change; `dune exec test/smoke.exe` to sanity-check.
- `opam pin add -y -k path bench-contract .` so the running-ng adapter can depend
  on it.
- Viz: `npm install`; `npm run dev` (preview) / `npm run build` (static → `dist/`).
  Both run `scripts/adapt.sh` first (the adapter → `./contract`); loaders then run
  the contract-only ingestor. `BENCH_RUN_DIR` selects the legacy run to adapt.

## Gotchas (hard-won — don't rediscover)

- **OxCaml overlay repos were removed from the switch.** They served `+ox`
  packages (e.g. `re 1.14.0+ox`) with `@@ portable` syntax that stock 5.4.1 can't
  parse. Keep this switch on the `default` repo only.
- **`ppx_deriving_jsonschema` is capped below 0.0.8** in `dune-project`. 0.0.8
  renamed the runtime functions the deriver emits, so `lib/schema` fails with
  `Unbound value list_jsonschema`; it also changes the `default`/nullability
  output, silently rewriting every `schema/json/*.json`. Raise the cap only
  together with a regeneration commit. Related: don't build this repo in the
  `running-ng-tools` switch — it's on an OCaml 5.5 trunk snapshot where ppxlib
  0.38 won't compile at all.
- **Generated artifacts drift if you skip the regen step.** The committed
  `schema/json/*.json` were once produced by an older deriver than the pinned
  one; the mismatch stayed invisible until someone rebuilt. After any
  `lib/schema` change run *both* generators and commit the result.
- **`ppx_deriving_yojson`'s `[@default]` drops a field equal to its default on
  output.** `schema_version` is intentionally mandatory (no default) so it's
  always emitted; `gen_schema` also relaxes `required` for defaulted collection
  fields so emitted records validate.
- **Layout:** per-tool NDJSON (`measurements/{olly,perf}.ndjson`) merged on ingest
  by identity. The record schema is unchanged; only the file layout differs.
- **Adapter vs native config_id parity** depends on `options` = raw
  `configure_args` on both sides (from `runbms.yml` for the adapter, the runtime
  spec for native). Don't reintroduce name-suffix parsing for options.
- **Background servers get reaped in this sandbox.** `npm run dev` / `python3 -m
  http.server` only stay up when run in the foreground; for a robust view,
  `npm run build` then serve `dist/` interactively.
- **olly has no `--version`** — its version is derived from the binary's owning
  opam switch or git checkout (see running-ng `contract/native.py`).

## Per-session workflow

1. Read `README.md` (overview), `docs/DATA_CONTRACT.md` (the spec), and this file.
2. Contract change → edit `lib/schema/` first, regenerate schema + vocab (and
   running-ng's `vocab.py`), then update `ingest/` and `src/`.
3. Validate: `dune exec test/smoke.exe`; rebuild `bin/ingest`; `npm run build`.
4. Commit only when asked; no `Co-Authored-By: Claude`.
