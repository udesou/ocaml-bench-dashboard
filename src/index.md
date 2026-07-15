# OCaml Benchmark Dashboard

```js
const measurements = await FileAttachment("data/measurements.json").json();
const manifest = await FileAttachment("data/manifest.json").json();
import * as B from "./components/bench.js";
```

```js
const cell = B.index(measurements);
const benches = B.benchmarksOf(measurements);
const configs = manifest.configs ?? [];
const cmps = B.comparisons(manifest);
```

```js
const mach = manifest.machine ?? {};
// Every machine field the contract carries, in a sensible order; only the ones
// actually recorded for this run are shown (legacy runs may only have a host).
const machineFields = [
  ["Host", mach.hostname],
  ["CPU", mach.cpu_model],
  ["Cores", mach.cores],
  ["Kernel", mach.kernel],
  ["Governor", mach.governor],
  ["isolcpus", mach.isolcpus],
  ["Turbo", mach.turbo == null ? null : mach.turbo ? "on" : "off"],
].filter(([, v]) => v != null && v !== "");
const runMeta = [
  ["Run", manifest.run_id],
  ["Created", manifest.created_at],
  ["Produced by", manifest._produced_by],
  ["Tools", Object.entries(manifest.tool_versions ?? {}).map(([t, v]) => `${t} ${v}`).join(" · ") || null],
].filter(([, v]) => v != null && v !== "");
const kv = (pairs) => html`<dl style="display:grid; grid-template-columns:auto 1fr; gap:.15rem 1rem; margin:.4rem 0 0;">
  ${pairs.map(([k, v]) => html`<dt style="color:var(--theme-foreground-muted); white-space:nowrap;">${k}</dt><dd style="margin:0; word-break:break-word;">${v}</dd>`)}
</dl>`;
display(html`<div class="grid grid-cols-2" style="gap:1rem;">
  <div class="card"><h2 style="margin:0 0 .1rem;">Machine</h2>${kv(machineFields)}</div>
  <div class="card"><h2 style="margin:0 0 .1rem;">Run</h2>${kv(runMeta)}
    <dl style="display:grid; grid-template-columns:auto 1fr; gap:.15rem 1rem; margin:.15rem 0 0;">
      <dt style="color:var(--theme-foreground-muted); white-space:nowrap;">Runtimes</dt>
      <dd style="margin:0;">${[...new Set(configs.map(B.label))].join(" · ")}</dd>
    </dl>
  </div>
</div>`);
```

Regression view: each **comparison declared in the run manifest** is rendered
below. Pick the metric to compare; negative Δ is better (fewer instructions,
less time). Thresholds: ±1% warn, ±3% regression/improvement.

If this run swept GC parameters, pick the point to compare at — otherwise the
same runtime shows up once per parameter combination. (Parameters with a single
value are omitted; use [Parameter sweeps](./sweep) to see the whole grid.)

```js
const metric = view(Inputs.select(B.METRICS.map((m) => m.name), {
  label: "Metric", value: "instructions", format: B.metricLabel,
}));
const pins = view(B.dimPinsInput(configs));
```

```js
const shown = B.filterByDims(configs, pins);
display(html`<div>${
  cmps.map((cmp) => {
    if (cmp.kind && cmp.kind !== "inter")
      return html`<div class="card"><h2>${cmp.label ?? cmp.kind}</h2>
        <p><em>“${cmp.kind}” comparisons are shown on the
        <a href="./sweep">Parameter sweeps</a> page.</em></p></div>`;
    const rows = B.interRows(cmp, { cell, benches, configs: shown, metric });
    if (!rows.length)
      return html`<div class="card"><h2>${cmp.label ?? "Comparison"}</h2><p><em>No overlapping data for ${B.metricLabel(metric)}.</em></p></div>`;
    const nImp = rows.filter((r) => r.verdict === "improvement").length;
    const nReg = rows.filter((r) => r.verdict === "regression").length;
    return html`<div>
      <h2>${cmp.label ?? "inter-runtime comparison"}</h2>
      <p>${nImp} improvement(s), ${nReg} regression(s) across ${new Set(rows.map((r) => r.benchmark)).size} benchmark(s).</p>
      ${B.deltaChart(rows, metric)}
      <details><summary>Table</summary>${B.deltaTable(rows)}</details>
    </div>`;
  })
}</div>`);
```

---

*This page renders the manifest's declared `comparisons`. See also
[Absolute values](./absolute), and
[Parameter sweeps](./sweep). Charts are Observable Plot in `src/` — edit freely.*
