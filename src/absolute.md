# Absolute values

Raw per-benchmark medians for each **selected config** (no baseline) — useful
when there isn't a single reference to compare against, or to sanity-check
magnitudes. Configs of the same runtime that differ only by a GC dimension (e.g.
`gc_plan=Bactrian` vs `LXR`) are shown as separate series.

```js
const measurements = await FileAttachment("data/measurements.json").json();
const manifest = await FileAttachment("data/manifest.json").json();
import * as B from "./components/bench.js";
```

<style>
.cfgpick { display: flex; flex-direction: column; gap: 0.4rem; margin: 0.3rem 0; }
.cfgpick-row { display: flex; flex-wrap: wrap; align-items: end; gap: 0.5rem; padding: 0.35rem 0.5rem; border: 1px solid var(--theme-foreground-faintest, #d0d0d0); border-radius: 6px; }
.cfgpick-dims { display: contents; }
.cfgpick-f { display: flex; flex-direction: column; font-size: 0.7rem; gap: 2px; }
.cfgpick-f span { opacity: 0.65; }
.cfgpick-rm { margin-left: auto; align-self: center; border: none; background: none; cursor: pointer; font-size: 1.1rem; opacity: 0.6; }
.cfgpick-rm:hover { opacity: 1; color: var(--theme-red, #d03b3b); }
.cfgpick-add { align-self: start; font-size: 0.8rem; cursor: pointer; }
</style>

```js
const cell = B.index(measurements);
const benches = B.benchmarksOf(measurements);
const configs = manifest.configs ?? [];
const cmps = B.comparisons(manifest);
```

Pick the configs to show — a runtime plus a value for each swept parameter
(`space_overhead`, `minor_heap`, `gc_plan`, …); **+ Add** another for more series.

```js
const metric = view(Inputs.select(B.METRICS.map((m) => m.name), {
  label: "Metric", value: "wall_time", format: B.metricLabel,
}));
```

```js
const dpick = B.defaultPick(configs, cmps);
const shown = view(B.configPicker(configs, {
  multiple: true, value: [dpick.baseline, ...dpick.variants],
}));
```

```js
const rows = B.absoluteRows({ cell, benches, configs: shown, metric });
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
