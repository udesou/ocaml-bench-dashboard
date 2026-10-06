#!/bin/sh
# Turn the run in $BENCH_RUN_DIR into ./contract for the dashboard to ingest.
# Runs before `npm run dev` and `npm run build`.
set -e

RUN_DIR="${BENCH_RUN_DIR:-$HOME/running-ng/gc-sweep-logs-pr14796/monolith-2026-05-25-Mon-102618}"
RUNNING_NG="${RUNNING_NG:-$HOME/running-ng}"
ADAPTER="${BENCH_ADAPTER:-$RUNNING_NG/contract-adapter/bin/adapter}"

if [ ! -d "$RUN_DIR" ]; then
  echo "adapt: BENCH_RUN_DIR does not exist: $RUN_DIR" >&2
  exit 1
fi

# Observable caches loader output keyed by the loader script, not by ./contract,
# so a changed BENCH_RUN_DIR would otherwise keep showing the previous run.
rm -rf src/.observablehq/cache/data 2>/dev/null || true

if [ -d "$RUN_DIR/contract/measurements" ]; then
  rm -rf contract && cp -r "$RUN_DIR/contract" contract
  echo "adapt: using native contract from $RUN_DIR/contract"
  exit 0
fi

# `running adapt` resolves runbms.yml anchors, giving precise runtime identity;
# the standalone adapter below only derives identity from filenames.
if [ -f "$RUNNING_NG/src/running/__main__.py" ] && command -v python3 >/dev/null 2>&1; then
  if PYTHONPATH="$RUNNING_NG/src" python3 -m running adapt "$RUN_DIR" -o contract; then
    exit 0
  fi
  echo "adapt: 'running adapt' failed; trying the standalone adapter binary" >&2
fi

if [ -x "$ADAPTER" ]; then
  if "$ADAPTER" "$RUN_DIR" contract; then
    exit 0
  fi
fi

echo "adapt: could not produce ./contract from $RUN_DIR." >&2
echo "  Build the adapter once:  (cd $RUNNING_NG/contract-adapter && ./build.sh)" >&2
echo "  or set BENCH_ADAPTER / RUNNING_NG, or point BENCH_RUN_DIR at a run dir." >&2
exit 1
