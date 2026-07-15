# Parameter sweeps

Heatmap of a metric across two swept dimensions (GC parameters). Only meaningful
for runs that swept parameters (e.g. `s` × `o`); for single-config runs there are
no dimensions to plot.

```js
const measurements = await FileAttachment("data/measurements.json").json();
const manifest = await FileAttachment("data/manifest.json").json();
import * as B from "./components/bench.js";
```

```js
const cell = B.index(measurements);
const benches = B.benchmarksOf(measurements);
const configs = manifest.configs ?? [];
const cmps = B.comparisons(manifest).filter((c) => !c.kind || c.kind === "inter");
// Only dimensions that actually vary — a parameter with a single value has
// nothing to sweep, so it is left out of the axis dropdowns.
const vdims = B.varyingDims(configs);
const dims = vdims.map((d) => d.dim);
```

```js
display(dims.length === 0
  ? html`<div class="card"><p><em>This run swept no parameters (no dimension has more than one value) — nothing to plot here.
      Point <code>BENCH_RUN_DIR</code> at a sweep run (e.g. a <code>gc-sweep-logs-sweep-s-o…</code> run) to use this page.</em></p></div>`
  : html`<p>Swept parameters in this run: <b>${dims.join(", ")}</b>.</p>`);
```

```js
const bench = view(Inputs.select(benches, { label: "Benchmark" }));
const metric = view(Inputs.select(B.METRICS.map((m) => m.name), { label: "Metric", value: "wall_time", format: B.metricLabel }));
const xDim = view(Inputs.select(dims, { label: "X dimension", value: dims[0], disabled: dims.length === 0 }));
const yDim = view(Inputs.select(dims, { label: "Y dimension", value: dims[1] ?? dims[0], disabled: dims.length < 2 }));
```

```js
// If more than two parameters vary, pin the ones not on an axis to a fixed
// value so each grid cell maps to a single config (no overplotting).
const pins = view(B.dimPinsInput(configs, [xDim, yDim]));
```

```js
display((() => {
  if (dims.length === 0) return html``;
  const rows = B.sweepRows({ cell, configs: B.filterByDims(configs, pins), bench, metric, xDim, yDim });
  if (!rows.length) return html`<div class="card"><p><em>No data for that selection.</em></p></div>`;
  return B.heatmap(rows, { metric, xDim, yDim });
})());
```

When two runtimes are compared, the grids above show each runtime's absolute
values; below is their **difference across the sweep** — for every parameter
point, how much the variant differs from the baseline. Negative (green) means
the variant is better.

```js
display((() => {
  if (dims.length === 0) return html``;
  const shown = B.filterByDims(configs, pins);
  const blocks = [];
  for (const cmp of cmps)
    for (const varSel of cmp.variants ?? []) {
      const baseLabel = B.label(B.resolve(shown, cmp.baseline)[0] ?? B.resolve(configs, cmp.baseline)[0] ?? { config_id: "?" });
      const varLabel = B.label(B.resolve(shown, varSel)[0] ?? B.resolve(configs, varSel)[0] ?? { config_id: "?" });
      const rows = B.sweepDeltaRows({ cell, configs: shown, bench, metric, xDim, yDim, baseSel: cmp.baseline, varSel });
      if (rows.length) blocks.push(html`<div><h3>${varLabel} vs ${baseLabel}</h3>${B.deltaHeatmap(rows, { metric, xDim, yDim, baseLabel, varLabel })}</div>`);
    }
  return blocks.length
    ? html`<div>${blocks}</div>`
    : html`<div class="card"><p><em>No inter-runtime comparison for this run (need two runtimes over the same parameter grid).</em></p></div>`;
})());
```

---

*See also [Overview](./index), [Absolute values](./absolute).*
