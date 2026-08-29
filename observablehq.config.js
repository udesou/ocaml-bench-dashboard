// Observable Framework configuration.
// The site is a thin rendering layer: all data comes from the OCaml ingester
// (bin/ingest) wired in as data loaders under src/data/; pages read the contract
// and render with Observable Plot.
export default {
  root: "src",
  title: "OCaml Benchmark Dashboard",
  // Page links keep their .html extension: the built site is served by plain
  // static file servers (python http.server behind the bench webview), which
  // do not resolve Observable's extensionless "clean" URLs.
  preserveExtension: true,
  pages: [
    { name: "Overview (regression)", path: "/index" },
    { name: "Absolute values", path: "/absolute" },
    { name: "Parameter sweeps", path: "/sweep" },
    { name: "Sweep curves", path: "/curves" },
    { name: "Space × time tradeoff", path: "/tradeoff" },
  ],
  toc: true,
};
