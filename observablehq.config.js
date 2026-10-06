// Observable Framework configuration; all data comes from the bin/ingest
// loaders under src/data/.
export default {
  root: "src",
  title: "OCaml Benchmark Dashboard",
  // Plain static servers (python http.server behind the bench webview) cannot
  // resolve Observable's extensionless URLs, so keep .html in page links.
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
