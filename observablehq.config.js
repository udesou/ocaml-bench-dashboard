// Observable Framework configuration.
// The site is a thin rendering layer: all data comes from the OCaml ingester
// (bin/ingest) wired in as data loaders under src/data/; pages read the contract
// and render with Observable Plot.
export default {
  root: "src",
  title: "OCaml Benchmark Dashboard",
  pages: [
    { name: "Overview (regression)", path: "/index" },
    { name: "Absolute values", path: "/absolute" },
    { name: "Parameter sweeps", path: "/sweep" },
  ],
  toc: true,
};
