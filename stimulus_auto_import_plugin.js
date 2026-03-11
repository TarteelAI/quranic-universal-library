const fs = require('fs');
const path = require('path');

// This esbuild plugin intercepts a virtual import (e.g., 'esbuild-stimulus-controllers')
// and generates code that imports and registers all Stimulus controllers dynamically
function stimulusAutoImportPlugin(options = {}) {
  const { 
    controllersDirectory = 'app/javascript/controllers',
    fileExtension = '_controller.js'
  } = options;

  return {
    name: 'stimulus-auto-import',
    setup(build) {
      const namespace = 'stimulus-auto-import-ns';
      const virtualModuleId = 'esbuild-stimulus-controllers';

      // 1. Intercept the virtual import
      build.onResolve({ filter: new RegExp(`^${virtualModuleId}$`) }, args => ({
        path: args.path,
        namespace,
      }));

      // 2. Load the virtual module by scanning the controllers directory
      build.onLoad({ filter: /.*/, namespace }, async () => {
        const controllersDir = path.resolve(process.cwd(), controllersDirectory);
        
        let contents = `import { application } from "./application";\n`;
        const controllers = [];

        function scanDirectory(dir, basePath = '') {
          if (!fs.existsSync(dir)) return;
          
          const files = fs.readdirSync(dir);
          
          for (const file of files) {
            const fullPath = path.join(dir, file);
            const stat = fs.statSync(fullPath);
            
            if (stat.isDirectory()) {
              scanDirectory(fullPath, path.join(basePath, file));
            } else if (file.endsWith(fileExtension) && !file.startsWith('_')) {
              // Convert filename to stimulus identifier 
              // e.g. "activities/fill_the_blanks_controller.js" -> "activities--fill-the-blanks"
              const nameWithoutExt = file.replace(fileExtension, '');
              let identifier = path.join(basePath, nameWithoutExt)
                .replace(/\\/g, '/')   // Normalize windows slashes
                .replace(/\//g, '--')  // Subdirectory separator
                .replace(/_/g, '-');   // Underscores to dashes
              
              // Special case mappings to not break existing HTML
              if (identifier === 'activities--fill-the-blanks') {
                identifier = 'activities--fill-in-blank';
              }
              
              controllers.push({
                identifier,
                importPath: `./${path.join(basePath, file).replace(/\\/g, '/')}`
              });
            }
          }
        }

        scanDirectory(controllersDir);

        controllers.forEach((controller, index) => {
          const variableName = `Controller${index}`;
          contents += `import ${variableName} from "${controller.importPath}";\n`;
          contents += `application.register("${controller.identifier}", ${variableName});\n`;
        });

        // Add a watch directory so esbuild rebuilds when controllers are added/removed
        return {
          contents,
          resolveDir: controllersDir,
          watchDirs: [controllersDir]
        };
      });
    },
  };
}

module.exports = stimulusAutoImportPlugin;
