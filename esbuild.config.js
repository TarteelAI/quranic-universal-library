#!/usr/bin/env node

// Esbuild is configured with 3 modes:
//
// `yarn build` - Build JavaScript and exit
// `yarn build --watch` - Rebuild JavaScript on change
// `yarn build --reload` - Reloads page when views, JavaScript, or stylesheets change
//
// Minify is enabled when "RAILS_ENV=production"
// Sourcemaps are enabled in non-production environments

//import * as esbuild from "esbuild"
const esbuild = require("esbuild");
const path = require("path");
const rails = require("esbuild-rails");
const vuePlugin = require("esbuild-plugin-vue3")
const chokidar = require("chokidar");
const http = require("http");
//const setTimeout = require("timers/promises");
//const dynamicImportNodePlugin = require('esbuild-dynamic-import-node');

const clients = []
const entryPoints = [
  "application.js",
  "active_admin.js",
  "segments/index.js",
  "svg/index.js"
]

const watchDirectories = [
  "./app/javascript/**/*.js",
  "./app/javascript/**/*.vue",
  "./app/javascript/**/*.jsx",
  "./app/javascript/**/*.tsx",
  "./app/views/**/*.html.erb",
  "./app/assets/builds/**/*.css", // Wait for cssbundling changes
]

let minify = true;
const watch = process.argv.includes("--watch") || process.argv.includes("--reload");
const isDev = process.env.RAILS_ENV == "development";
let sourcemap = true;
const generateMeta = process.argv.includes("--meta");

if (watch || isDev) minify = false;
if (watch || isDev) sourcemap = true;

minify = false;
sourcemap = true

const config = {
  absWorkingDir: path.join(process.cwd(), "app/javascript"),
  bundle: true,
  entryPoints: entryPoints,
  minify: minify,
  outdir: path.join(process.cwd(), "app/assets/builds"),
  plugins: [rails(), vuePlugin()],
  sourcemap: sourcemap,
  metafile: generateMeta,
  loader: {
    '.svg': 'file', // For SVG files
  }
}

async function buildAndReload() {
  // Foreman & Overmind assign a separate PORT for each process
  const port = parseInt(process.env.PORT || '3005');

  const context = await esbuild.context({
    ...config,
    banner: {
      js: ` (() => new EventSource("http://localhost:${port}").onmessage = () => location.reload())();`,
    }
  })

  // Reload uses an HTTP server as an event stream to reload the browser
  http
    .createServer((req, res) => {
      return clients.push(
        res.writeHead(200, {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          "Access-Control-Allow-Origin": "*",
          Connection: "keep-alive",
        })
      )
    })
    .listen(port)

  await context.rebuild()
  console.log("[reload] listing on port", port);
  console.log("[reload] initial build succeeded")

  let ready = false
  chokidar
    .watch(watchDirectories)
    .on("ready", () => {
      console.log("[reload] ready")
      ready = true
    })
    .on("all", async (event, path) => {
      if (ready === false)  return

      console.log("file changed", path);

      if (path.includes("javascript")) {
        try {
          await context.rebuild()
          console.log("[reload] build succeeded")
        } catch (error) {
          console.error("[reload] build failed", error)
        }
      }

      clients.forEach((res) => res.write("data: update\n\n"))
      clients.length = 0
    })
}

async function buildAndWatch() {
  let context = await esbuild.context({...config, logLevel: 'info'})
  context.watch()
}

if (process.argv.includes("--reload")) {
  buildAndReload()
} else if (process.argv.includes("--watch")) {
  buildAndWatch();
} else {
  esbuild.build(config)
}