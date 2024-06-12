const vuePlugin = require("esbuild-plugin-vue3")
const path = require("path");
const watch = process.argv.includes("--watch");
let minify = !watch;

var buildOptions = {
  entryPoints: ["segments/index.js", "svg/index.js"],
  bundle: true,
  outdir: path.join(process.cwd(), "app/assets/builds"),
  absWorkingDir: path.join(process.cwd(), "app/javascript"),
  logLevel: "info",
  plugins: [vuePlugin()],
  minify: minify,
  sourcemap: watch,
  define: {
    "process.env.NODE_ENV": JSON.stringify("production"),
  }
};

if (watch) {
  buildOptions.watch = {
    onRebuild(error, result) {
      if (error) console.error("watch build failed:", error);
      else console.log("watch build succeeded:", result);
    }
  };
}

require("esbuild").build(buildOptions);