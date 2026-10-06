# Space × time tradeoff

A GC parameter point never just "wins": it buys time with memory, or memory with
time. This page plots both axes at once — a **space** metric against a **time**
metric, one point per configuration — so a sweep reads as a *curve of available
tradeoffs* rather than two separate rankings.

The dashed line through the enlarged points is the **Pareto frontier**: the
configurations no other configuration of the same runtime beats on *both* axes.
Everything off the frontier is strictly worse than something on it. Comparing two
runtimes then means comparing frontiers — a runtime whose frontier sits below and
to the left offers a better tradeoff *at every operating point*, which a
single-metric Δ can hide.

Labels mark each frontier's anchors: its cheapest-space end, its fastest end, and
its **knee** — the point nearest the ideal corner once both axes are normalized,
i.e. the compromise configuration. Hover any point for its full parameter set,
and open the table below for every frontier configuration.

Related: [Parameter sweeps](./sweep) is one metric over two parameters,
[Sweep curves](./curves) is one metric over one parameter; this page is two
metrics over the whole parameter set.

```js
const measurements = await FileAttachment("data/measurements.json").json();
const manifest = await FileAttachment("data/manifest.json").json();
import * as B from "./components/bench.js";
```

```js
// Series colors are validated per surface, so charts re-render on theme flip.
const dark = Generators.dark();
```

```js
const cell = B.index(measurements);
const benches = B.benchmarksOf(measurements);
const configs = manifest.configs ?? [];
const cmps = B.comparisons(manifest).filter((c) => !c.kind || c.kind === "inter");
// A comparison axis (e.g. gc_plan) identifies a runtime: a series here, not a
// parameter to trace along.
const cmpDims = B.comparisonDims(cmps);
const dims = B.varyingDims(configs).map((d) => d.dim).filter((d) => !cmpDims.includes(d));
```

<div class="card">

## Selection

```js
const bench = view(Inputs.select([B.ALL_BENCHES, ...benches], { label: "Benchmark" }));
const xMetric = view(Inputs.select(["max_rss", "major_words", "page_faults", "minor_words"], { label: "Space (x)", value: "max_rss", format: B.metricLabel }));
const yMetric = view(Inputs.select(["wall_time", "cpu_time", "gc_time", "gc_overhead", "mean_latency", "instructions", "cycles"], { label: "Time (y)", value: "wall_time", format: B.metricLabel }));
```

```js
// Unpinned parameters are extra frontier candidates, not noise.
const traceDim = view(Inputs.select(["(none)", ...dims], { label: "Trace along", value: dims[0] ?? "(none)" }));
```

```js
const facetDim = view(Inputs.select(["(none)", ...dims.filter((d) => d !== traceDim)], { label: "Facet by", value: "(none)" }));
```

```js
const pins = view(B.dimPinsInput(configs, [traceDim, facetDim].filter((d) => d && d !== "(none)"), { allowAll: true }));
const showPareto = view(Inputs.toggle({ label: "Pareto frontier", value: true }));
```

</div>

```js
const trace = traceDim === "(none)" ? null : traceDim;
const facet = facetDim === "(none)" ? null : facetDim;
const shown = B.filterByDims(configs, pins);
const val = B.valueTable({ cell, configs: shown, benches, bench, metrics: [xMetric, yMetric] });
const rows = B.withPareto(B.tradeoffRows({ val, configs: shown, xMetric, yMetric, traceDim: trace, facetDim: facet, sweepDims: dims }));
const xLabel = B.tradeoffAxis(xMetric, bench, val.benches.length);
const yLabel = B.tradeoffAxis(yMetric, bench, val.benches.length);
```

```js
display(html`<div>
  ${dims.length
    ? html`<p>Swept parameters in this run: <b>${dims.join(", ")}</b>${trace ? html` — tracing along <b>${trace}</b>` : ""}. Lower-left is better on both axes.</p>`
    : html`<p><em>This run swept no parameters, so each runtime contributes a single point — the tradeoff between runtimes is still visible, but there is no frontier to walk.</em></p>`}
  ${val.dropped.length
    ? html`<p><small><em>Aggregating ${val.benches.length} of ${benches.length} benchmarks; excluded because they were not measured under every shown configuration: <b>${val.dropped.join(", ")}</b>. An unbalanced set would give the two runtimes' geomeans different suites to summarize.</em></small></p>`
    : ""}
</div>`);
```

```js
display((() => {
  if (!rows.length) return html`<div class="card"><p><em>No data for that selection.</em></p></div>`;
  const nSeries = new Set(rows.map((r) => r.runtime)).size;
  const chart = B.tradeoffChart(rows, { xMetric, yMetric, traceDim: trace, facetDim: facet, xLabel, yLabel, pareto: showPareto, dark, absolute: bench !== B.ALL_BENCHES });
  // Past three adjacent series, hue stops being separable under color-vision
  // deficiency; symbols and labels still carry identity.
  return nSeries > 3
    ? html`<div>${chart}<p><small><em>${nSeries} series in one panel — hue alone is no longer reliable at this count (symbols and the table below still identify them). Facet or pin a dimension to get back to ≤ 3.</em></small></p></div>`
    : chart;
})());
```

```js
display(rows.some((r) => r.front)
  ? html`<details><summary>Frontier configurations (table)</summary>${B.paretoTable(rows, { xMetric, yMetric, bench })}</details>`
  : html``);
```

## Cost / benefit quadrant

The same tradeoff expressed as a **comparison**: each point is one parameter
point, positioned by how much space the variant costs (x) and how much time it
costs (y) relative to the baseline *at that same parameter point*. Lower-left is
better on both; the off-diagonal quadrants are where a real tradeoff is being
made. Each trace's two ends are labelled with their traced-parameter value.

```js
display((() => {
  const blocks = [];
  for (const cmp of cmps)
    for (const varSel of cmp.variants ?? []) {
      const dRows = B.tradeoffDeltaRows({ val, configs: shown, xMetric, yMetric, baseSel: cmp.baseline, varSel, traceDim: trace, facetDim: facet, sweepDims: dims });
      if (!dRows.length) continue;
      const b = B.resolve(shown, cmp.baseline)[0] ?? B.resolve(configs, cmp.baseline)[0];
      const v = B.resolve(shown, varSel)[0] ?? B.resolve(configs, varSel)[0];
      blocks.push(html`<div><h3>${B.compareTitle(v, b, configs)}</h3>${B.tradeoffDeltaChart(dRows, { xMetric, yMetric, traceDim: trace, facetDim: facet, dark })}</div>`);
    }
  return blocks.length
    ? html`<div>${blocks}</div>`
    : html`<div class="card"><p><em>No inter-runtime comparison for this run (need two runtimes over the same parameter points).</em></p></div>`;
})());
```

> **Reading the aggregate.** With *★ all benchmarks* selected, each benchmark is
> first divided by the best value any shown configuration reached on it, then the
> ratios are combined as a geometric mean — so no single large benchmark
> dominates, and `1.0` means "as good as the best point in this view". The
> normalizer cancels in a ratio, so the quadrant chart above is exactly the
> geometric mean of the per-benchmark Δs either way.

---

*See also [Overview](./index), [Absolute values](./absolute), [Parameter sweeps](./sweep), [Sweep curves](./curves).*
