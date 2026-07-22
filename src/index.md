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

Regression view. Pick a **baseline** and one or more **configs to compare**
against it. This defaults to the comparison declared in the run manifest, but you
can choose any pair — e.g. compare two MMTk plans directly (LXR vs Bactrian).
Negative Δ is better (fewer instructions, less time). Thresholds: ±1% warn, ±3%
regression/improvement. Config labels include their GC dimensions `{gc_plan=…}`.

```js
const metric = view(Inputs.select(B.METRICS.map((m) => m.name), {
  label: "Metric", value: "instructions", format: B.metricLabel,
}));
const dflt = B.defaultCompare(configs, cmps);
```

```js
const baseline = view(Inputs.select(configs, {
  label: "Baseline", format: B.label, value: dflt.baseline,
}));
```

```js
const variants = view(Inputs.checkbox(
  configs.filter((c) => c.config_id !== baseline.config_id),
  { label: "Compare", format: B.label,
    value: dflt.variants.filter((c) => c.config_id !== baseline.config_id) }));
```

```js
display((() => {
  if (!variants.length)
    return html`<div class="card"><p><em>Select one or more configs to compare against <b>${B.label(baseline)}</b>.</em></p></div>`;
  const rows = B.interRows(
    { kind: "inter", baseline: { config_id: baseline.config_id },
      variants: variants.map((c) => ({ config_id: c.config_id })) },
    { cell, benches, configs, metric });
  if (!rows.length)
    return html`<div class="card"><p><em>No overlapping data for ${B.metricLabel(metric)} between these configs.</em></p></div>`;
  const nImp = rows.filter((r) => r.verdict === "improvement").length;
  const nReg = rows.filter((r) => r.verdict === "regression").length;
  return html`<div>
    <h2>vs ${B.label(baseline)}</h2>
    <p>${nImp} improvement(s), ${nReg} regression(s) across ${new Set(rows.map((r) => r.benchmark)).size} benchmark(s).</p>
    ${B.deltaChart(rows, metric)}
    <details><summary>Table</summary>${B.deltaTable(rows)}</details>
  </div>`;
})());
```

---

*This page renders the manifest's declared `comparisons`. See also
[Absolute values](./absolute), and
[Parameter sweeps](./sweep). Charts are Observable Plot in `src/` — edit freely.*
