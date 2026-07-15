#!/bin/sh
# Producer step: turn the benchmark run in $BENCH_RUN_DIR into contract artifacts
# in ./contract (which the dashboard then ingests). Runs automatically before
# `npm run dev` and `npm run build`.
#
#   Pick the run to show:   export BENCH_RUN_DIR=/path/to/a/run-dir
#
# It handles three cases automatically:
#   1. the run already has a native contract/  -> copy it in (nothing to convert);
#   2. otherwise convert via `running adapt`    -> resolves runbms.yml YAML anchors
#      (running-ng, PyYAML) for precise runtime identity;
#   3. if running-ng isn't available            -> fall back to the standalone
#      adapter binary (filename-derived identity).
set -e

RUN_DIR="${BENCH_RUN_DIR:-$HOME/running-ng/gc-sweep-logs-pr14796/monolith-2026-05-25-Mon-102618}"
RUNNING_NG="${RUNNING_NG:-$HOME/running-ng}"
ADAPTER="${BENCH_ADAPTER:-$RUNNING_NG/contract-adapter/bin/adapter}"

if [ ! -d "$RUN_DIR" ]; then
  echo "adapt: BENCH_RUN_DIR does not exist: $RUN_DIR" >&2
  exit 1
fi

# Invalidate Observable's data-loader cache so the site re-reads the new run.
# Framework caches loader output keyed by the loader *script*, not by ./contract,
# so without this a changed BENCH_RUN_DIR would keep showing the previous run.
rm -rf src/.observablehq/cache/data 2>/dev/null || true

# 1. native run: already has a contract/ — just use it.
if [ -d "$RUN_DIR/contract/measurements" ]; then
  rm -rf contract && cp -r "$RUN_DIR/contract" contract
  echo "adapt: using native contract from $RUN_DIR/contract"
  exit 0
fi

# 2. legacy run: prefer `running adapt` (resolves runbms.yml anchors -> precise identity).
if [ -f "$RUNNING_NG/src/running/__main__.py" ] && command -v python3 >/dev/null 2>&1; then
  if PYTHONPATH="$RUNNING_NG/src" python3 -m running adapt "$RUN_DIR" -o contract; then
    exit 0
  fi
  echo "adapt: 'running adapt' failed; trying the standalone adapter binary" >&2
fi

# 3. fallback: standalone adapter binary.
if [ -x "$ADAPTER" ]; then
  if "$ADAPTER" "$RUN_DIR" contract; then
    exit 0
  fi
fi

echo "adapt: could not produce ./contract from $RUN_DIR." >&2
echo "  Build the adapter once:  (cd $RUNNING_NG/contract-adapter && ./build.sh)" >&2
echo "  or set BENCH_ADAPTER / RUNNING_NG, or point BENCH_RUN_DIR at a run dir." >&2
exit 1
