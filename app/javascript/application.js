// Entry point for the build script in your package.json
import "./libs/jquery";
import "@hotwired/turbo-rails";

import "trix";
import "@rails/actiontext";
import "./controllers";
import "./utils/ayah-player";

// Alert dismiss functionality is now handled by alert_controller.js
// for cleaner separation of concerns
