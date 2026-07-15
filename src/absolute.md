# Absolute values

Raw per-benchmark medians for each runtime (no baseline) — useful when there
isn't a single reference to compare against, or to sanity-check magnitudes.

```js
const measurements = await FileAttachment("data/measurements.json").json();
const manifest = await FileAttachment("data/manifest.json").json();
import * as B from "./components/bench.js";
```

```js
const cell = B.index(measurements);
const benches = B.benchmarksOf(measurements);
const configs = manifest.configs ?? [];
```

```js
const metric = view(Inputs.select(B.METRICS.map((m) => m.name), {
  label: "Metric", value: "wall_time", format: B.metricLabel,
}));
const pins = view(B.dimPinsInput(configs));
```

```js
const rows = B.absoluteRows({ cell, benches, configs: B.filterByDims(configs, pins), metric });
display(rows.length
  ? B.absoluteChart(rows, metric)
  : html`<div class="card"><p><em>No data for ${B.metricLabel(metric)}.</em></p></div>`);
```

```js
display(Inputs.table(
  rows.map((r) => ({ benchmark: r.benchmark, runtime: r.runtime, [B.metricLabel(metric)]: r.value })),
  { sort: "benchmark" }
));
```

---

*See also [Overview](./index), [Parameter sweeps](./sweep).*
