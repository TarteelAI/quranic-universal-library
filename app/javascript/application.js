// Entry point for the build script in your package.json
import "./libs/jquery";
import "@hotwired/turbo-rails"
// Bootstrap removed - using custom Stimulus controllers instead
import "trix"
import "@rails/actiontext"
import "./controllers"
import "./utils/ayah-player"