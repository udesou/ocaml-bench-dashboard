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
      <dd style="margin:0;">${[...new Set(configs.map((c) => B.runtimeId(c)))].join(" · ")}</dd>
    </dl>
  </div>
</div>`);
```

<style>
.cfgpick { display: flex; flex-direction: column; gap: 0.4rem; margin: 0.3rem 0; }
.cfgpick-row { display: flex; flex-wrap: wrap; align-items: end; gap: 0.5rem; padding: 0.35rem 0.5rem; border: 1px solid var(--theme-foreground-faintest, #d0d0d0); border-radius: 6px; }
.cfgpick-dims { display: contents; }
.cfgpick-f { display: flex; flex-direction: column; font-size: 0.7rem; gap: 2px; }
.cfgpick-f span { opacity: 0.65; text-transform: none; }
.cfgpick-rm { margin-left: auto; align-self: center; border: none; background: none; cursor: pointer; font-size: 1.1rem; opacity: 0.6; }
.cfgpick-rm:hover { opacity: 1; color: var(--theme-red, #d03b3b); }
.cfgpick-add { align-self: start; font-size: 0.8rem; cursor: pointer; }
</style>

Regression view. Pick a **baseline** and a **comparison** — each is a runtime,
plus a value for each swept parameter (`space_overhead`, `minor_heap`, `gc_plan`,
…) if the run has any. Defaults to the comparison declared in the run manifest,
but any pair works (e.g. LXR vs Bactrian, or trunk vs the PR at a chosen
`(s, o)`). Negative Δ is better; thresholds ±1% warn, ±3% regression/improvement.

```js
const metric = view(Inputs.select(B.METRICS.map((m) => m.name), {
  label: "Metric", value: "instructions", format: B.metricLabel,
}));
const dflt = B.defaultPick(configs, cmps);
```

**Baseline**

```js
const baseline = view(B.configPicker(configs, { value: dflt.baseline }));
```

**Compare**

```js
const variant = view(B.configPicker(configs, { value: dflt.variants[0] }));
```

```js
display((() => {
  if (!baseline || !variant)
    return html`<div class="card"><p><em>Pick a baseline and a comparison config.</em></p></div>`;
  if (variant.config_id === baseline.config_id)
    return html`<div class="card"><p><em>Baseline and comparison are the same config — change one.</em></p></div>`;
  const rows = B.interRows(
    { kind: "inter", baseline: { config_id: baseline.config_id },
      variants: [{ config_id: variant.config_id }] },
    { cell, benches, configs, metric });
  if (!rows.length)
    return html`<div class="card"><p><em>No overlapping data for ${B.metricLabel(metric)} between these configs.</em></p></div>`;
  const nImp = rows.filter((r) => r.verdict === "improvement").length;
  const nReg = rows.filter((r) => r.verdict === "regression").length;
  return html`<div>
    <h2>${B.compareTitle(variant, baseline, configs)}</h2>
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
