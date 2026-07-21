# Sweep curves

How a metric responds to **one** swept parameter, drawn as a line per runtime.
This is the shape used in
[ocaml/ocaml#14796](https://github.com/ocaml/ocaml/pull/14796#issuecomment-4924501898)
to compare OCaml versions as the space-overhead (`o`) parameter varies — e.g.
`max_rss` or `gc_overhead` on the y axis, `space_overhead` on the x axis, one
line per compiler. Pick a second varying parameter as a **facet** to get the
small-multiples grid from that comment.

For a two-dimensional view of a single metric use [Parameter sweeps](./sweep)
(heatmaps); this page is for the one-parameter *response curve*.

```js
const measurements = await FileAttachment("data/measurements.json").json();
const manifest = await FileAttachment("data/manifest.json").json();
import * as B from "./components/bench.js";
```

```js
const cell = B.index(measurements);
const benches = B.benchmarksOf(measurements);
const configs = manifest.configs ?? [];
// Only dimensions that actually vary can be a curve's x axis or facet.
const vdims = B.varyingDims(configs);
const dims = vdims.map((d) => d.dim);
```

```js
display(dims.length === 0
  ? html`<div class="card"><p><em>This run swept no parameters (no dimension has more than one value) — there is no curve to draw.
      Point <code>BENCH_RUN_DIR</code> at a sweep run (e.g. a <code>gc-sweep-logs-…</code> run) to use this page.</em></p></div>`
  : html`<p>Swept parameters in this run: <b>${dims.join(", ")}</b>.</p>`);
```

```js
const bench = view(Inputs.select(benches, { label: "Benchmark" }));
const metric = view(Inputs.select(B.METRICS.map((m) => m.name), { label: "Metric (y)", value: "max_rss", format: B.metricLabel }));
const xDim = view(Inputs.select(dims, { label: "Parameter (x)", value: dims[0], disabled: dims.length === 0 }));
// The facet is optional; "(none)" draws a single panel with all runtimes overlaid.
const facetDim = view(Inputs.select(["(none)", ...dims.filter((d) => d !== xDim)], { label: "Facet by", value: "(none)" }));
```

```js
// Pin any remaining varying dimensions (not x, not the facet) so each x point
// maps to a single config per runtime — otherwise several configs collapse onto
// the same x and the line becomes meaningless.
const pins = view(B.dimPinsInput(configs, [xDim, facetDim].filter((d) => d && d !== "(none)")));
```

```js
display((() => {
  if (dims.length === 0) return html``;
  const facet = facetDim === "(none)" ? null : facetDim;
  const rows = B.curveRows({ cell, configs: B.filterByDims(configs, pins), bench, metric, xDim, facetDim: facet });
  if (!rows.length) return html`<div class="card"><p><em>No data for that selection.</em></p></div>`;
  return B.curveChart(rows, { metric, xDim, facetDim: facet });
})());
```

> **Note.** The theoretical *target lines* in the PR comment (expected memory in
> the absence / presence of ephemerons) are properties of that specific
> microbenchmark, not of the generic contract, so they are not drawn here. A run
> that emits a target as a metric (e.g. `max_rss_target`) would show up as just
> another selectable series.

---

*See also [Overview](./index), [Absolute values](./absolute), [Parameter sweeps](./sweep).*
