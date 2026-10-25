// WebGL rendering of the QUL shard ring, ported from the Spline scene.
//
// The scene is drawn with plain WebGL 1 rather than a scene graph library: one
// chip mesh drawn 16 times, two shadow-mapped spot lights, and a Kawase bloom
// pass composited over the result. The constants below come from the Spline
// scene (scene.splinecode) unless noted otherwise.
import { SHARD_SCENE as SCENE } from "./scene_data";

const CHIP_COUNT = 16;
const CHIP_TWEEN_SECONDS = 50; // Linear ping-pong between the two cloner states.
// One noise value per chip. It drives the spin, tilt, and scale of that chip.
const CHIP_NOISE = [
  0.4239, 0.4784, 0.5042, 0.5926, 0.5997, 0.6124, 0.6174, 0.6647,
  0.6308, 0.5483, 0.503, 0.6069, 0.4789, 0.4357, 0.4091, 0.4264,
];
const NOISE_DRIFT = 0.02; // Approximates the slow noise movement in Spline.
const NOISE_DRIFT_SPEED = 0.075; // Radians per second.

// Spot lights. "Spot Light 2" eases between two states, 5 seconds each way.
const LIGHT_TWEEN_SECONDS = 5;
const LIGHT_FROM = { position: [940.784, 70.04, 389.408], color: [0.55286, 0.22562, 0.88805], intensity: 1.877 };
const LIGHT_TO = { position: [1390.78, -237.96, 443.41], color: [0.84625, 0.18895, 0.18895], intensity: 2 };
const SPOT1_POSITION = [751.69, -220.43, -298.17];
const SPOT1_COLOR = [2.68581, 2.38266, 0.241]; // Color multiplied by intensity.
const SPOT_AXES = [[0.99923, 0.00694, 0.03857], [0.9734, -0.04056, -0.22549]];
const SPOT_RANGES = [7010, 8628];
const SPOT_ANGLE = Math.PI / 6;
const SHADOW_NEAR = 100;
const SHADOW_MAP_SIZE = 1024;

const FOV_Y = (45 * Math.PI) / 180;
const BOUNDING_RADIUS = 300; // Contains the ring at every animation state.
const BACKGROUND = [0.01363, 0.01363, 0.0153];
const BLOOM_KERNEL = [0, 1, 2, 2, 3];
const BLOOM_BLUR_SCALE = 0.389;
const BLOOM_INTENSITY = 1.259;
const BLOOM_OPACITY = 0.7;

// Framing. The authored Spline camera assumes a full-window canvas; here the
// ring sits in a hero half-column or a short devise panel, so the viewing angle
// is kept but the distance is re-derived per container shape. These are the
// fraction of the container's shorter side the ring should span.
const FILL_LARGE = 0.92;
// Small panels (the devise hero is only 30vh tall on phones) are short and wide,
// so a ring bounded by the inscribed circle leaves the box looking empty. Going
// past 1 lets the outermost chips clip the short edge at full fan-out, which
// fills the panel without the ring losing its silhouette.
const FILL_SMALL = 1.2;
const SMALL_CANVAS = 380;
const FIT_SAMPLES = [0, 0.25, 0.5, 0.75, 1]; // Tween states sampled for the fit.
const FIT_CANDIDATES = 256; // Outermost sample points kept for the fit passes.
const FIT_PASSES = 6;

// Performance limits.
const MAX_DEVICE_PIXEL_RATIO = 2;

// The camera leans toward the pointer as it moves over the ring. This is a
// parallax lean of the whole scene, independent of the drag spin below, and the
// two layer: you can tilt by hovering and turn by grabbing at the same time.
const TILT_MAX = 0.3; // Radians of lean at the canvas edges.
const TILT_EASE = 0.06; // Share of the remaining lean applied per 60 Hz frame.

// Grab the ring and swing it around its centre, like turning a wheel. The ring
// tracks the pointer's angle 1:1 while held; on release it is a spring-damper,
// so how hard you threw it decides how far it carries before settling back to
// the authored angle.
const SPIN_SIGN = 1; // Maps screen-clockwise pointer travel to a clockwise ring, so it follows the hand.
const SPIN_MAX = 2 * Math.PI; // Clamp, so a long drag cannot wind up forever.
const SPIN_MAX_VELOCITY = 16; // rad/s ceiling on a flick.
const SPIN_STIFFNESS = 26; // Spring pulling the ring home, rad/s^2 per rad.
const SPIN_DAMPING = 7.5; // ~0.73 of critical: settles in under a second, barely overshoots.
const SPIN_STEP = 1 / 120; // Fixed integration step, so a long frame cannot blow the spring up.
const GRAB_MIN_RADIUS = 28; // px. Nearer the centre than this, the grab angle is too noisy to use.
const MAX_PIXELS = 4.2e6; // Upper limit for the drawing buffer size.
const MIN_FRAME_MS = 12.5; // Limits rendering to about 60 frames per second.

// Colors are Display P3 values, as in Spline. Without a P3 canvas, this converts them to sRGB.
const P3_TO_SRGB = `
  vec3 outputColor(vec3 color) {
    #ifdef CONVERT_P3
    // Display P3 and sRGB use the same transfer function.
    vec3 c = clamp(color, 0.0, 1.0);
    vec3 linear = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
    linear = clamp(mat3(1.2249401, -0.0420569, -0.0196376, -0.2249404, 1.0420571, -0.0786361,
                        0.0, 0.0, 1.0982735) * linear, 0.0, 1.0);
    return mix(1.055 * pow(linear, vec3(1.0 / 2.4)) - 0.055, linear * 12.92, step(linear, vec3(0.0031308)));
    #else
    return color;
    #endif
  }`;

const CHIP_VS = `
  attribute vec3 aPosition;
  attribute vec3 aNormal;
  uniform mat4 uModel;
  uniform mat4 uViewProjection;
  uniform mat3 uNormalMatrix;
  uniform vec3 uSpotPosition[2];
  uniform vec3 uCameraPosition;
  uniform mat4 uShadowMatrix[2];
  varying vec3 vNormal;
  varying vec3 vToCamera;
  varying vec3 vToSpot0;
  varying vec3 vToSpot1;
  varying vec4 vShadow0;
  varying vec4 vShadow1;
  varying float vGradient;
  const float SHADOW_NORMAL_BIAS = 1.0;
  void main() {
    vec4 world = uModel * vec4(aPosition, 1.0);
    vNormal = uNormalMatrix * aNormal;
    // Vectors to the camera and the lights are linear in the position,
    // so interpolation is exact and medium precision is sufficient.
    vToCamera = uCameraPosition - world.xyz;
    vToSpot0 = uSpotPosition[0] - world.xyz;
    vToSpot1 = uSpotPosition[1] - world.xyz;
    vec4 biased = vec4(world.xyz + normalize(vNormal) * SHADOW_NORMAL_BIAS, 1.0);
    vShadow0 = uShadowMatrix[0] * biased;
    vShadow1 = uShadowMatrix[1] * biased;
    // Linear gradient along the local x axis of the chip.
    vGradient = (132.0 - aPosition.x) / 190.0;
    gl_Position = uViewProjection * world;
  }`;

const CHIP_FS = `
  precision mediump float;
  #ifdef GL_FRAGMENT_PRECISION_HIGH
  precision highp float;
  #endif
  uniform vec3 uSpotColor[2];
  uniform sampler2D uShadowMap0;
  uniform sampler2D uShadowMap1;
  varying vec3 vNormal;
  varying vec3 vToCamera;
  varying vec3 vToSpot0;
  varying vec3 vToSpot1;
  varying vec4 vShadow0;
  varying vec4 vShadow1;
  varying float vGradient;
  ${P3_TO_SRGB}

  const vec3 COLOR0 = vec3(0.88402, 0.92133, 0.97012);
  const vec3 COLOR1 = vec3(0.53969, 1.0, 0.47573);
  const vec3 COLOR2 = vec3(0.33333, 0.84706, 0.60664);
  const float STOP0 = 0.026684;
  const float STOP1 = 0.408671;
  const float STOP2 = 0.976755;
  const vec3 SKY = vec3(0.62059);      // Hemisphere light, intensity included.
  const vec3 GROUND = vec3(0.38235);
  const vec3 SPOT0_AXIS = vec3(${SPOT_AXES[0].join(", ")});
  const vec3 SPOT1_AXIS = vec3(${SPOT_AXES[1].join(", ")});
  const float SHADOW_MAP_SIZE = ${SHADOW_MAP_SIZE.toFixed(1)};
  const float SHADOW_NORMAL_BIAS = 1.0;
  const float SHADOW_DEPTH_BIAS = 0.5;

  float unpackDepth(vec4 color) {
    return dot(color, vec4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0));
  }

  float shadowSample(sampler2D map, vec2 texel, float depth) {
    return step(depth, unpackDepth(texture2D(map, (texel + 0.5) / SHADOW_MAP_SIZE)));
  }

  // Percentage-closer filtering with bilinear weights over 4 texels.
  float shadow(sampler2D map, vec4 coord, vec3 toLight, vec3 n, float range) {
    vec2 uv = coord.xy / coord.w * 0.5 + 0.5;
    if (coord.w <= 0.0 || any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 1.0;
    float depth = (length(n * SHADOW_NORMAL_BIAS - toLight) - SHADOW_DEPTH_BIAS) / range;
    vec2 p = uv * SHADOW_MAP_SIZE - 0.5;
    vec2 i = floor(p);
    vec2 f = p - i;
    float a = shadowSample(map, i, depth);
    float b = shadowSample(map, i + vec2(1.0, 0.0), depth);
    float c = shadowSample(map, i + vec2(0.0, 1.0), depth);
    float d = shadowSample(map, i + vec2(1.0, 1.0), depth);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
  }

  vec3 spotLight(vec3 toLight, vec3 axis, vec3 color, float coneCos, float penumbraCos,
                 float range, float visibility, vec3 n, vec3 v, vec3 albedo, inout vec3 specular) {
    float dist = length(toLight);
    vec3 l = toLight / dist;
    float attenuation = smoothstep(coneCos, penumbraCos, dot(l, axis))
                      * clamp(1.0 - dist / range, 0.0, 1.0) * visibility;
    vec3 irradiance = color * attenuation * max(dot(n, l), 0.0);
    // Blinn-Phong with specular color 0.2 and shininess 5 (three.js r149).
    vec3 h = normalize(l + v);
    float vh = max(dot(v, h), 0.0);
    float fresnel = exp2((-5.55473 * vh - 6.98316) * vh);
    float blinn = 0.875 * pow(max(dot(n, h), 0.0), 5.0);
    specular += irradiance * (0.2 + 0.8 * fresnel) * blinn;
    return irradiance * albedo;
  }

  void main() {
    vec3 n = normalize(vNormal);
    vec3 v = normalize(vToCamera);

    // Spline "rainbow" layer: a gray band pattern that depends on the view angle.
    float phase = -9.0 * dot(v, n);
    float band = cos(phase);
    #ifdef HAS_DERIVATIVES
    // Average the bands over the pixel footprint to prevent shimmer on the rims.
    float halfWidth = max(0.5 * fwidth(phase), 1e-3);
    band *= clamp(sin(halfWidth) / halfWidth, 0.0, 1.0);
    #endif
    float bandGray = 0.5 + 0.5 * band;

    vec3 gradient = mix(COLOR0, COLOR1, clamp((vGradient - STOP0) / (STOP1 - STOP0), 0.0, 1.0));
    gradient = mix(gradient, COLOR2, clamp((vGradient - STOP1) / (STOP2 - STOP1), 0.0, 1.0));

    // Overlay blend of the band pattern and the gradient.
    vec3 albedo = clamp(mix(1.0 - 2.0 * (1.0 - bandGray) * (1.0 - gradient),
                            2.0 * bandGray * gradient, step(bandGray, 0.5)), 0.0, 1.0);

    float shadow0 = shadow(uShadowMap0, vShadow0, vToSpot0, n, ${SPOT_RANGES[0].toFixed(1)});
    float shadow1 = shadow(uShadowMap1, vShadow1, vToSpot1, n, ${SPOT_RANGES[1].toFixed(1)});

    vec3 specular = vec3(0.0);
    vec3 lit = albedo * mix(GROUND, SKY, 0.5 * n.y + 0.5);
    lit += spotLight(vToSpot0, SPOT0_AXIS, uSpotColor[0], 0.8660, 0.8666, ${SPOT_RANGES[0].toFixed(1)},
                     shadow0, n, v, albedo, specular);
    lit += spotLight(vToSpot1, SPOT1_AXIS, uSpotColor[1], 0.8660, 0.9135, ${SPOT_RANGES[1].toFixed(1)},
                     shadow1, n, v, albedo, specular);
    lit += specular;

    // The lighting layer has 60% opacity over the unlit color.
    vec3 color = mix(albedo, lit, 0.6);

    #ifdef BRIGHT
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    // Stored at half value so that colors above 1 survive the 8-bit target.
    gl_FragColor = vec4(0.5 * color * smoothstep(0.52, 0.545, luminance), 1.0);
    #else
    float noise = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    gl_FragColor = vec4(outputColor(color) + (noise - 0.5) / 255.0, 1.0);
    #endif
  }`;

// Stores the distance to the light, divided by the light range, in 8-bit channels.
const SHADOW_VS = `
  attribute vec3 aPosition;
  uniform mat4 uModel;
  uniform mat4 uViewProjection;
  uniform vec3 uLightPosition;
  varying vec3 vFromLight;
  void main() {
    vec4 world = uModel * vec4(aPosition, 1.0);
    vFromLight = world.xyz - uLightPosition;
    gl_Position = uViewProjection * world;
  }`;

const SHADOW_FS = `
  precision mediump float;
  #ifdef GL_FRAGMENT_PRECISION_HIGH
  precision highp float;
  #endif
  uniform float uInverseRange;
  varying vec3 vFromLight;
  void main() {
    vec4 encoded = fract(length(vFromLight) * uInverseRange * vec4(1.0, 255.0, 65025.0, 16581375.0));
    gl_FragColor = encoded - encoded.yzww * vec4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
  }`;

// Kawase blur, matching the bloom effect that Spline uses.
const BLUR_VS = `
  attribute vec2 aPosition;
  uniform vec2 uOffset;
  varying vec2 vUv0;
  varying vec2 vUv1;
  varying vec2 vUv2;
  varying vec2 vUv3;
  void main() {
    vec2 uv = aPosition * 0.5 + 0.5;
    vUv0 = uv + vec2(-uOffset.x, uOffset.y);
    vUv1 = uv + uOffset;
    vUv2 = uv - uOffset;
    vUv3 = uv + vec2(uOffset.x, -uOffset.y);
    gl_Position = vec4(aPosition, 0.0, 1.0);
  }`;

const BLUR_FS = `
  precision mediump float;
  uniform sampler2D uTexture;
  varying vec2 vUv0;
  varying vec2 vUv1;
  varying vec2 vUv2;
  varying vec2 vUv3;
  void main() {
    gl_FragColor = 0.25 * (texture2D(uTexture, vUv0) + texture2D(uTexture, vUv1)
                         + texture2D(uTexture, vUv2) + texture2D(uTexture, vUv3));
  }`;

const COMPOSITE_VS = `
  attribute vec2 aPosition;
  void main() { gl_Position = vec4(aPosition, 0.0, 1.0); }`;

// Drawn with screen blending: result = bloom + scene * (1 - bloom).
const COMPOSITE_FS = `
  precision mediump float;
  uniform sampler2D uTexture;
  uniform vec2 uInverseSize;
  ${P3_TO_SRGB}
  void main() {
    vec3 bloom = min(texture2D(uTexture, gl_FragCoord.xy * uInverseSize).rgb * ${(2 * BLOOM_INTENSITY).toFixed(4)}, 1.0);
    gl_FragColor = vec4(outputColor(bloom) * ${BLOOM_OPACITY.toFixed(2)}, 1.0);
  }`;

// ---------- Matrix helpers (column-major) ----------

function multiply(a, b, out, offset) {
  for (let col = 0; col < 4; col++) {
    for (let row = 0; row < 4; row++) {
      let sum = 0;
      for (let k = 0; k < 4; k++) sum += a[k * 4 + row] * b[col * 4 + k];
      out[offset + col * 4 + row] = sum;
    }
  }
}

function perspective(fovY, aspect, near, far) {
  const f = 1 / Math.tan(fovY / 2);
  return [f / aspect, 0, 0, 0, 0, f, 0, 0,
    0, 0, (far + near) / (near - far), -1, 0, 0, (2 * far * near) / (near - far), 0];
}

// View matrix from the camera axes (x, y, z) and position.
function view(x, y, z, p) {
  const dot = (a) => a[0] * p[0] + a[1] * p[1] + a[2] * p[2];
  return [x[0], y[0], z[0], 0, x[1], y[1], z[1], 0, x[2], y[2], z[2], 0, -dot(x), -dot(y), -dot(z), 1];
}

// CSS "ease-in-out", cubic-bezier(0.42, 0, 0.58, 1).
function easeInOut(x) {
  const curve = (t, p1, p2) => 3 * (1 - t) * (1 - t) * t * p1 + 3 * (1 - t) * t * t * p2 + t * t * t;
  let t = x;
  for (let i = 0; i < 8; i++) {
    const slope = 3 * (1 - t) * (1 - t) * 0.42 + 6 * (1 - t) * t * 0.16 + 3 * t * t * 0.42;
    t = Math.min(1, Math.max(0, t - (curve(t, 0.42, 0.58) - x) / Math.max(slope, 1e-4)));
  }
  return curve(t, 0, 1);
}

function pingPong(time, seconds) {
  const cycle = (time / seconds) % 2;
  return cycle < 1 ? cycle : 2 - cycle;
}

export default class ShardRing {
  constructor(canvas, container) {
    this.canvas = canvas;
    this.container = container || canvas.parentElement;
    this.disposed = false;
    this.running = false;
    this.frameId = 0;
    this.lastFrame = 0;
    this.contextLost = false;
    this.hasRendered = false;

    this.gl = canvas.getContext("webgl", {
      alpha: false, antialias: true, depth: true, stencil: false,
      premultipliedAlpha: false, preserveDrawingBuffer: false,
    });
    if (!this.gl) throw new Error("WebGL unavailable");
    this.convertP3 = !this.useDisplayP3();

    this.width = 0;
    this.height = 0;
    this.halfWidth = 0;
    this.halfHeight = 0;
    this.scissor = [0, 0, 0, 0];
    this.projection = null;
    this.viewProjection = new Float32Array(16);
    this.cameraPosition = new Float32Array(3);
    this.models = new Float32Array(16 * CHIP_COUNT);
    this.normals = new Float32Array(9 * CHIP_COUNT);
    this.spotPositions = new Float32Array([0, 0, 0].concat(SPOT1_POSITION));
    this.spotColors = new Float32Array([0, 0, 0].concat(SPOT1_COLOR));
    this.shadowMatrices = new Float32Array(32);
    this.ring = SCENE.parent;
    this.ringSpun = SCENE.parent.slice(); // ring's 3x3, re-derived per frame from `spin`.
    this.time = 0;
    this.tilt = { x: 0, y: 0, targetX: 0, targetY: 0 };
    this.spin = 0;
    this.spinVelocity = 0;
    this.centre = { x: 0, y: 0 };
    this.drag = { active: false, pointerId: null, angle: 0, time: 0 };

    // The authored camera gives the viewing angle; resize() re-derives the
    // distance along it so the ring frames itself in any container shape.
    const c = SCENE.cam;
    this.cameraAxes = [[c[0], c[1], c[2]], [c[4], c[5], c[6]], [c[8], c[9], c[10]]];
    const authored = [c[12], c[13], c[14]];
    this.cameraDistance = Math.hypot(authored[0], authored[1], authored[2]) || 735;
    this.cameraDirection = authored.map((value) => value / this.cameraDistance);

    this.buildFitSamples();

    this.boundResize = () => this.handleResize();
    this.boundPointerMove = (event) => this.handlePointerMove(event);
    this.boundPointerDown = (event) => this.handlePointerDown(event);
    this.boundPointerUp = (event) => this.handlePointerUp(event);
    this.boundMouseOut = (event) => {
      // Leaving the window entirely, rather than crossing between elements.
      if (!event.relatedTarget) this.tilt.targetX = this.tilt.targetY = 0;
    };
    this.boundContextLost = (event) => {
      event.preventDefault();
      this.contextLost = true;
      this.stop();
    };
    this.boundContextRestored = () => {
      this.contextLost = false;
      this.initResources();
      this.handleResize();
    };

    window.addEventListener("resize", this.boundResize);
    window.addEventListener("pointermove", this.boundPointerMove, { passive: true });
    document.addEventListener("mouseout", this.boundMouseOut);
    canvas.addEventListener("pointerdown", this.boundPointerDown);
    canvas.addEventListener("pointerup", this.boundPointerUp);
    canvas.addEventListener("pointercancel", this.boundPointerUp);
    canvas.style.cursor = "grab";
    // Vertical panning still belongs to the page, so on touch only the sideways
    // part of a swing reaches us and dragging the ring never traps the scroll.
    canvas.style.touchAction = "pan-y";
    canvas.addEventListener("webglcontextlost", this.boundContextLost);
    canvas.addEventListener("webglcontextrestored", this.boundContextRestored);

    // The hero column can change size without the window doing so (layout
    // shifts, the devise modal), so track the canvas box directly too.
    if ("ResizeObserver" in window) {
      this.resizeObserver = new ResizeObserver(this.boundResize);
      this.resizeObserver.observe(canvas);
    }

    this.initResources();
    this.handleResize();
  }

  // ---------- WebGL setup ----------

  // Some browsers accept a Display P3 canvas but still show it as sRGB. This draws a P3 color
  // and reads it back through an sRGB 2D canvas: with real P3 output, the browser converts it.
  useDisplayP3() {
    const gl = this.gl;
    if (!("drawingBufferColorSpace" in gl)) return false;
    gl.drawingBufferColorSpace = "display-p3";
    if (gl.drawingBufferColorSpace !== "display-p3") return false;
    let red = 0;
    try {
      const probe = document.createElement("canvas").getContext("2d", { willReadFrequently: true });
      gl.clearColor(0.3, 0.6, 0.4, 1); // In sRGB about (36, 158, 97). Unconverted, red stays 77.
      gl.clear(gl.COLOR_BUFFER_BIT);
      probe.drawImage(this.canvas, 0, 0, 1, 1);
      red = probe.getImageData(0, 0, 1, 1).data[0];
    } catch (error) {
      return true; // Cannot check. Trust the setting.
    }
    if (red < 56) return true;
    gl.drawingBufferColorSpace = "srgb";
    return false;
  }

  compile(type, source) {
    const gl = this.gl;
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS) && !gl.isContextLost()) {
      throw new Error(gl.getShaderInfoLog(shader));
    }
    return shader;
  }

  createProgram(vertexSource, fragmentSource, uniformNames) {
    const gl = this.gl;
    const program = gl.createProgram();
    gl.attachShader(program, this.compile(gl.VERTEX_SHADER, vertexSource));
    gl.attachShader(program, this.compile(gl.FRAGMENT_SHADER, fragmentSource));
    gl.bindAttribLocation(program, 0, "aPosition");
    gl.bindAttribLocation(program, 1, "aNormal");
    gl.linkProgram(program);
    const uniforms = {};
    uniformNames.forEach((name) => { uniforms[name] = gl.getUniformLocation(program, name); });
    return { program, uniforms };
  }

  createTarget(withDepth, filter) {
    const gl = this.gl;
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    const framebuffer = gl.createFramebuffer();
    const depth = withDepth ? gl.createRenderbuffer() : null;
    return { texture, framebuffer, depth };
  }

  sizeTarget(target, w, h) {
    const gl = this.gl;
    gl.bindTexture(gl.TEXTURE_2D, target.texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, target.texture, 0);
    if (target.depth) {
      gl.bindRenderbuffer(gl.RENDERBUFFER, target.depth);
      gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, w, h);
      gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, target.depth);
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  }

  initResources() {
    const gl = this.gl;
    const colorHeader = this.convertP3 ? "#define CONVERT_P3\n" : "";
    const header = colorHeader + (gl.getExtension("OES_standard_derivatives")
      ? "#extension GL_OES_standard_derivatives : enable\n#define HAS_DERIVATIVES\n" : "");
    const chipUniforms = ["uModel", "uViewProjection", "uNormalMatrix", "uSpotPosition", "uSpotColor",
      "uCameraPosition", "uShadowMatrix", "uShadowMap0", "uShadowMap1"];
    this.programs = {
      chip: this.createProgram(CHIP_VS, header + CHIP_FS, chipUniforms),
      bright: this.createProgram(CHIP_VS, header + "#define BRIGHT\n" + CHIP_FS, chipUniforms),
      shadow: this.createProgram(SHADOW_VS, SHADOW_FS, ["uModel", "uViewProjection", "uLightPosition", "uInverseRange"]),
      blur: this.createProgram(BLUR_VS, BLUR_FS, ["uTexture", "uOffset"]),
      composite: this.createProgram(COMPOSITE_VS, colorHeader + COMPOSITE_FS, ["uTexture", "uInverseSize"]),
    };
    [this.programs.chip, this.programs.bright].forEach((entry) => {
      gl.useProgram(entry.program);
      gl.uniform1i(entry.uniforms.uShadowMap0, 1);
      gl.uniform1i(entry.uniforms.uShadowMap1, 2);
    });

    const vertices = new Float32Array(SCENE.pos.length * 2);
    for (let i = 0; i < SCENE.pos.length; i += 3) {
      vertices.set(SCENE.pos.slice(i, i + 3), i * 2);
      vertices.set(SCENE.nor.slice(i, i + 3), i * 2 + 3);
    }
    this.chipBuffers = { vertex: gl.createBuffer(), index: gl.createBuffer() };
    gl.bindBuffer(gl.ARRAY_BUFFER, this.chipBuffers.vertex);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.chipBuffers.index);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(SCENE.idx), gl.STATIC_DRAW);

    this.quadBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quadBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);

    this.bloomTargets = [this.createTarget(true, gl.LINEAR), this.createTarget(false, gl.LINEAR)];
    this.shadowTargets = [this.createTarget(true, gl.NEAREST), this.createTarget(true, gl.NEAREST)];
    this.shadowTargets.forEach((target) => this.sizeTarget(target, SHADOW_MAP_SIZE, SHADOW_MAP_SIZE));
    this.updateShadowMatrix(1, SPOT1_POSITION);
    gl.enable(gl.CULL_FACE);
    this.width = 0; // Forces the next resize to size the bloom targets.
  }

  // Shadow camera of a spot light: looks along the light axis, with world up.
  updateShadowMatrix(index, position) {
    const z = SPOT_AXES[index];
    const length = Math.hypot(z[2], z[0]);
    const x = [z[2] / length, 0, -z[0] / length];
    const y = [z[1] * x[2], z[2] * x[0] - z[0] * x[2], -z[1] * x[0]];
    const matrix = perspective(2 * SPOT_ANGLE, 1, SHADOW_NEAR, SPOT_RANGES[index]);
    multiply(matrix, view(x, y, z, position), this.shadowMatrices, index * 16);
  }

  // ---------- Framing ----------

  // World-space chip vertices at a few tween states. resize() projects these to
  // find the ring's true on-screen extent, the same way the authored camera is
  // framed in Spline, so the ring fills its container at any aspect ratio.
  buildFitSamples() {
    const points = [];
    const models = new Float32Array(16 * CHIP_COUNT);
    const normals = new Float32Array(9 * CHIP_COUNT);

    FIT_SAMPLES.forEach((w) => {
      this.writeChipMatrices(models, normals, w, 0);
      for (let chip = 0; chip < CHIP_COUNT; chip++) {
        const m = chip * 16;
        for (let i = 0; i < SCENE.pos.length; i += 3) {
          const x = SCENE.pos[i];
          const y = SCENE.pos[i + 1];
          const z = SCENE.pos[i + 2];
          points.push(
            models[m] * x + models[m + 4] * y + models[m + 8] * z + models[m + 12],
            models[m + 1] * x + models[m + 5] * y + models[m + 9] * z + models[m + 13],
            models[m + 2] * x + models[m + 6] * y + models[m + 10] * z + models[m + 14],
          );
        }
      }
    });

    this.fitPoints = new Float32Array(points);
  }

  // Projected radius of the sample set, in "half-height" units: NDC runs -1..1
  // on both axes, so scaling x by the aspect ratio makes a radius here match
  // pixels on screen. `indices` limits the scan to the outermost candidates.
  fitRadius(distance, aspect, indices) {
    this.setCamera(distance, aspect);
    const matrix = new Float32Array(16);
    multiply(this.projection, this.cameraView, matrix, 0);
    const points = this.fitPoints;
    const count = indices ? indices.length : points.length / 3;
    const radii = new Float64Array(count);

    for (let n = 0; n < count; n++) {
      const i = (indices ? indices[n] : n) * 3;
      const x = points[i];
      const y = points[i + 1];
      const z = points[i + 2];
      const w = matrix[3] * x + matrix[7] * y + matrix[11] * z + matrix[15];
      const sx = (matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12]) / w;
      const sy = (matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13]) / w;
      radii[n] = Math.hypot(sx * aspect, sy);
    }

    let outer = 0;
    for (let n = 0; n < count; n++) if (radii[n] > outer) outer = radii[n];
    return { outer, radii };
  }

  // Distance at which the ring spans `fill` of the shorter side. The projected
  // radius is very nearly inversely proportional to distance, so a couple of
  // correction passes converge.
  fitDistance(fill, aspect) {
    let distance = this.cameraDistance;

    // First pass over every sample; later passes only need the outermost ones,
    // which a pure change of distance barely reorders.
    const first = this.fitRadius(distance, aspect, null);
    const order = Array.from(first.radii.keys())
      .sort((a, b) => first.radii[b] - first.radii[a])
      .slice(0, FIT_CANDIDATES);

    // In these units the frame reaches 1 vertically but `aspect` horizontally,
    // so the ring has to clear the smaller of the two or it overflows the
    // narrow axis as it turns.
    const limit = fill * Math.min(1, aspect);
    let outer = first.outer;

    for (let pass = 0; pass < FIT_PASSES; pass++) {
      const correction = outer / limit;
      if (Math.abs(correction - 1) < 0.002) break;
      distance *= correction;
      outer = this.fitRadius(distance, aspect, order).outer;
    }

    this.setCamera(distance, aspect);
    return distance;
  }

  // Publish the ring's centre so the QUL lockup can sit on it. The authored
  // camera aims at the origin, so the ring turns about this point on screen.
  publishRingCentre() {
    const m = this.viewProjection;
    const w = m[15];
    // Also kept in CSS pixels: the drag measures its angle around this point.
    this.centre.x = ((m[12] / w) * 0.5 + 0.5) * this.canvas.clientWidth;
    this.centre.y = ((-m[13] / w) * 0.5 + 0.5) * this.canvas.clientHeight;
    if (!this.container) return;
    const style = this.container.style;
    style.setProperty("--qul-ring-cx", `${this.centre.x.toFixed(1)}px`);
    style.setProperty("--qul-ring-cy", `${this.centre.y.toFixed(1)}px`);
    this.container.dataset.qulRingReady = "true";
  }

  // ---------- Sizing ----------

  resize() {
    const cssWidth = this.canvas.clientWidth || 1;
    const cssHeight = this.canvas.clientHeight || 1;
    let ratio = Math.min(window.devicePixelRatio || 1, MAX_DEVICE_PIXEL_RATIO);
    ratio = Math.min(ratio, Math.sqrt(MAX_PIXELS / (cssWidth * cssHeight)));
    const w = Math.max(1, Math.round(cssWidth * ratio));
    const h = Math.max(1, Math.round(cssHeight * ratio));
    if (w === this.width && h === this.height) return false;

    const gl = this.gl;
    this.width = this.canvas.width = w;
    this.height = this.canvas.height = h;
    this.halfWidth = Math.max(1, w >> 1);
    this.halfHeight = Math.max(1, h >> 1);
    this.bloomTargets.forEach((target) => this.sizeTarget(target, this.halfWidth, this.halfHeight));

    const aspect = w / h;
    const fill = Math.min(cssWidth, cssHeight) < SMALL_CANVAS ? FILL_SMALL : FILL_LARGE;
    // fitDistance leaves the camera at the distance it settled on.
    this.fitDistance(fill, aspect);
    this.updateView();
    this.publishRingCentre();

    // Screen rectangle that contains the bounding sphere. Bloom work stays inside it.
    const m = this.viewProjection;
    let x0 = 1, y0 = 1, x1 = -1, y1 = -1;
    for (let i = 0; i < 8; i++) {
      const x = i & 1 ? BOUNDING_RADIUS : -BOUNDING_RADIUS;
      const y = i & 2 ? BOUNDING_RADIUS : -BOUNDING_RADIUS;
      const z = i & 4 ? BOUNDING_RADIUS : -BOUNDING_RADIUS;
      const clipW = m[3] * x + m[7] * y + m[11] * z + m[15];
      const sx = (m[0] * x + m[4] * y + m[8] * z + m[12]) / clipW;
      const sy = (m[1] * x + m[5] * y + m[9] * z + m[13]) / clipW;
      x0 = Math.min(x0, sx); x1 = Math.max(x1, sx);
      y0 = Math.min(y0, sy); y1 = Math.max(y1, sy);
    }
    const margin = 16;
    const left = Math.max(0, Math.floor((x0 * 0.5 + 0.5) * this.width) - margin);
    const bottom = Math.max(0, Math.floor((y0 * 0.5 + 0.5) * this.height) - margin);
    const right = Math.min(this.width, Math.ceil((x1 * 0.5 + 0.5) * this.width) + margin);
    const top = Math.min(this.height, Math.ceil((y1 * 0.5 + 0.5) * this.height) + margin);
    this.scissor = [left, bottom, Math.max(0, right - left), Math.max(0, top - bottom)];
    return true;
  }

  // ---------- Animation ----------

  // View matrix for a camera at `distance` along the authored direction, and the
  // matching projection. Near and far bracket the ring at whatever distance the
  // fit lands on, so a wide or very short container cannot clip it.
  setCamera(distance, aspect) {
    const position = this.cameraDirection.map((value) => value * distance);
    const [ax, ay, az] = this.cameraAxes;
    this.cameraView = view(ax, ay, az, position);
    this.projection = perspective(
      FOV_Y, aspect,
      Math.max(1, distance - 2 * BOUNDING_RADIUS),
      distance + 4 * BOUNDING_RADIUS,
    );
    this.tiltedView = this.cameraView.slice();
  }

  // Leans the camera around the ring centre by the current tilt. It orbits the
  // centre rather than panning, so the ring centre stays in the same place on
  // screen: the bloom rectangle, the lockup position and the grab angle all
  // stay valid while it leans.
  updateView() {
    const base = this.cameraView;
    const tilted = this.tiltedView;
    const ca = Math.cos(this.tilt.x), sa = Math.sin(this.tilt.x);
    const cb = Math.cos(this.tilt.y), sb = Math.sin(this.tilt.y);
    const r = [[cb, 0, sb], [sa * sb, ca, -sa * cb], [-ca * sb, sa, ca * cb]]; // rotateX * rotateY
    for (let col = 0; col < 3; col++) {
      for (let row = 0; row < 3; row++) {
        tilted[col * 4 + row] = r[row][0] * base[col * 4] + r[row][1] * base[col * 4 + 1]
          + r[row][2] * base[col * 4 + 2];
      }
    }
    multiply(this.projection, tilted, this.viewProjection, 0);
    for (let i = 0; i < 3; i++) {
      this.cameraPosition[i] = -(tilted[i * 4] * tilted[12] + tilted[i * 4 + 1] * tilted[13]
        + tilted[i * 4 + 2] * tilted[14]);
    }
  }

  updateLight(time) {
    const k = easeInOut(pingPong(time, LIGHT_TWEEN_SECONDS));
    const intensity = LIGHT_FROM.intensity + (LIGHT_TO.intensity - LIGHT_FROM.intensity) * k;
    for (let i = 0; i < 3; i++) {
      this.spotPositions[i] = LIGHT_FROM.position[i] + (LIGHT_TO.position[i] - LIGHT_FROM.position[i]) * k;
      this.spotColors[i] = (LIGHT_FROM.color[i] + (LIGHT_TO.color[i] - LIGHT_FROM.color[i]) * k) * intensity;
    }
    this.updateShadowMatrix(0, this.spotPositions);
  }

  // The ring's orientation turned by `spin` about its own axis (local Y, the
  // axis the chips are arranged around). Post-multiplying rather than nudging
  // each chip's angle keeps the assembly rigid: the chips carry their own tilt
  // and spacing around with them, so it reads as the whole ring turning.
  spinRing(spin) {
    const ring = this.ring;
    const out = this.ringSpun;
    if (!spin) return ring;
    const cs = Math.cos(spin), ss = Math.sin(spin);
    for (let row = 0; row < 3; row++) {
      const c0 = ring[row];
      const c2 = ring[8 + row];
      out[row] = c0 * cs - c2 * ss;
      out[4 + row] = ring[4 + row];
      out[8 + row] = c0 * ss + c2 * cs;
    }
    return out;
  }

  // Cloner state at tween progress `w` (0 to 1), with `time` driving the slow
  // noise drift. Pulled out of updateChips so buildFitSamples can reuse it.
  writeChipMatrices(models, normals, w, time) {
    const ring = this.spinRing(this.spin);
    const radius = 143 + 7 * w;
    // Writes ring * (x, y, z) into out at the given offset.
    const transform = (out, offset, x, y, z) => {
      out[offset] = ring[0] * x + ring[4] * y + ring[8] * z;
      out[offset + 1] = ring[1] * x + ring[5] * y + ring[9] * z;
      out[offset + 2] = ring[2] * x + ring[6] * y + ring[10] * z;
    };

    for (let i = 0; i < CHIP_COUNT; i++) {
      const noise = CHIP_NOISE[i] + NOISE_DRIFT * Math.sin(NOISE_DRIFT_SPEED * time + i * 1.7);
      const amount = w * noise;
      // Chip rotation = rotateY(alignment + tilt) * rotateZ(spin).
      const alpha = ((10 - i * 22.5) * Math.PI) / 180 + 0.4363 * amount;
      const beta = 62.832 * amount;
      const cA = Math.cos(alpha), sA = Math.sin(alpha), cB = Math.cos(beta), sB = Math.sin(beta);
      const scaleX = 1.1 + 0.96 * amount;
      const scaleY = 1 + 0.2 * amount;
      const angle = (i * Math.PI) / 8;
      const m = i * 16, n = i * 9;
      transform(models, m, cA * cB * scaleX, sB * scaleX, -sA * cB * scaleX);
      transform(models, m + 4, -cA * sB * scaleY, cB * scaleY, sA * sB * scaleY);
      transform(models, m + 8, sA, 0, cA);
      transform(models, m + 12, radius * Math.cos(angle), 0, radius * Math.sin(angle));
      models[m + 3] = models[m + 7] = models[m + 11] = 0;
      models[m + 15] = 1;
      transform(normals, n, (cA * cB) / scaleX, sB / scaleX, (-sA * cB) / scaleX);
      transform(normals, n + 3, (-cA * sB) / scaleY, cB / scaleY, (sA * sB) / scaleY);
      transform(normals, n + 6, sA, 0, cA);
    }
  }

  updateChips(time) {
    // Tween progress, 0 to 1 and back.
    this.writeChipMatrices(this.models, this.normals, pingPong(time, CHIP_TWEEN_SECONDS), time);
  }

  // ---------- Rendering ----------

  drawChips(entry, matrix) {
    const gl = this.gl;
    gl.useProgram(entry.program);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.chipBuffers.vertex);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.chipBuffers.index);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 24, 0);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 24, 12);
    gl.uniformMatrix4fv(entry.uniforms.uViewProjection, false, matrix);
    gl.enable(gl.DEPTH_TEST);
    for (let i = 0; i < CHIP_COUNT; i++) {
      gl.uniformMatrix4fv(entry.uniforms.uModel, false, this.models.subarray(i * 16, i * 16 + 16));
      if (entry.uniforms.uNormalMatrix) {
        gl.uniformMatrix3fv(entry.uniforms.uNormalMatrix, false, this.normals.subarray(i * 9, i * 9 + 9));
      }
      gl.drawElements(gl.TRIANGLES, SCENE.idx.length, gl.UNSIGNED_SHORT, 0);
    }
    gl.disable(gl.DEPTH_TEST);
    gl.disableVertexAttribArray(1);
  }

  drawLitChips(entry) {
    const gl = this.gl;
    gl.useProgram(entry.program);
    gl.uniform3fv(entry.uniforms.uSpotPosition, this.spotPositions);
    gl.uniform3fv(entry.uniforms.uSpotColor, this.spotColors);
    gl.uniform3fv(entry.uniforms.uCameraPosition, this.cameraPosition);
    gl.uniformMatrix4fv(entry.uniforms.uShadowMatrix, false, this.shadowMatrices);
    this.drawChips(entry, this.viewProjection);
  }

  useQuad(entry) {
    const gl = this.gl;
    gl.useProgram(entry.program);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quadBuffer);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    gl.uniform1i(entry.uniforms.uTexture, 0);
  }

  render() {
    const gl = this.gl;
    const scissor = this.scissor;
    gl.enableVertexAttribArray(0);

    // Shadow maps. Back faces are drawn, as three.js does, to reduce self-shadowing.
    gl.viewport(0, 0, SHADOW_MAP_SIZE, SHADOW_MAP_SIZE);
    gl.clearColor(1, 1, 1, 1);
    gl.cullFace(gl.FRONT);
    this.shadowTargets.forEach((target, index) => {
      gl.bindFramebuffer(gl.FRAMEBUFFER, target.framebuffer);
      gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
      gl.useProgram(this.programs.shadow.program);
      gl.uniform3fv(this.programs.shadow.uniforms.uLightPosition, this.spotPositions.subarray(index * 3, index * 3 + 3));
      gl.uniform1f(this.programs.shadow.uniforms.uInverseRange, 1 / SPOT_RANGES[index]);
      this.drawChips(this.programs.shadow, this.shadowMatrices.subarray(index * 16, index * 16 + 16));
    });
    gl.cullFace(gl.BACK);
    this.shadowTargets.forEach((target, index) => {
      gl.activeTexture(gl.TEXTURE1 + index);
      gl.bindTexture(gl.TEXTURE_2D, target.texture);
    });
    gl.activeTexture(gl.TEXTURE0);

    gl.viewport(0, 0, this.halfWidth, this.halfHeight);
    gl.enable(gl.SCISSOR_TEST);
    gl.scissor(scissor[0] >> 1, scissor[1] >> 1, (scissor[2] >> 1) + 2, (scissor[3] >> 1) + 2);
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomTargets[0].framebuffer);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    this.drawLitChips(this.programs.bright);

    this.useQuad(this.programs.blur);
    BLOOM_KERNEL.forEach((kernel, pass) => {
      const offset = (kernel + 0.5) * BLOOM_BLUR_SCALE;
      gl.bindFramebuffer(gl.FRAMEBUFFER, this.bloomTargets[(pass + 1) % 2].framebuffer);
      gl.bindTexture(gl.TEXTURE_2D, this.bloomTargets[pass % 2].texture);
      gl.uniform2f(this.programs.blur.uniforms.uOffset, offset / this.halfWidth, offset / this.halfHeight);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    });
    gl.disable(gl.SCISSOR_TEST);

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, this.width, this.height);
    gl.clearColor(BACKGROUND[0], BACKGROUND[1], BACKGROUND[2], 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    this.drawLitChips(this.programs.chip);

    this.useQuad(this.programs.composite);
    gl.bindTexture(gl.TEXTURE_2D, this.bloomTargets[BLOOM_KERNEL.length % 2].texture);
    gl.uniform2f(this.programs.composite.uniforms.uInverseSize, 1 / this.width, 1 / this.height);
    gl.enable(gl.SCISSOR_TEST);
    gl.scissor(scissor[0], scissor[1], scissor[2], scissor[3]);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_COLOR);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.disable(gl.BLEND);
    gl.disable(gl.SCISSOR_TEST);
  }

  draw() {
    this.updateView();
    this.updateChips(this.time);
    this.updateLight(this.time);
    this.render();
    this.hasRendered = true;
  }

  // ---------- Loop ----------

  loop(now) {
    if (!this.running || this.disposed) return;
    this.frameId = requestAnimationFrame((next) => this.loop(next));

    const elapsed = now - this.lastFrame;
    if (elapsed < MIN_FRAME_MS) return;
    this.lastFrame = now;
    if (elapsed < 250) this.time += elapsed / 1000; // Longer gaps mean the page was paused.

    const ease = 1 - Math.pow(1 - TILT_EASE, Math.min(elapsed, 250) / (1000 / 60));
    this.tilt.x += (this.tilt.targetX - this.tilt.x) * ease;
    this.tilt.y += (this.tilt.targetY - this.tilt.y) * ease;

    // Let go and the throw carries, then springs back to the authored angle.
    if (!this.drag.active && (this.spin || this.spinVelocity)) {
      this.stepSpin(elapsed / 1000);
    }

    this.draw();
  }

  start() {
    if (this.running || this.disposed || this.contextLost) return;
    this.running = true;
    this.lastFrame = performance.now();
    this.frameId = requestAnimationFrame((now) => this.loop(now));
  }

  stop() {
    this.running = false;
    if (this.frameId) {
      cancelAnimationFrame(this.frameId);
      this.frameId = 0;
    }
  }

  // Draw a single frame — used when motion is disabled (prefers-reduced-motion)
  // so the ring still shows, just static. Start partway through the chip tween
  // so the still frame shows the chips fanned out rather than edge-on.
  renderStill() {
    if (this.disposed || this.contextLost) return;
    if (!this.hasRendered) this.time = 0.35 * CHIP_TWEEN_SECONDS;
    this.draw();
  }

  // Resizing clears the canvas, so draw at once. Otherwise the empty canvas
  // shows until the next frame.
  handleResize() {
    if (this.disposed || this.contextLost) return;
    const changed = this.resize();
    if (changed || !this.running) this.draw();
  }

  updateTiltTarget(event) {
    const rect = this.canvas.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    const nx = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    const ny = ((event.clientY - rect.top) / rect.height) * 2 - 1;
    this.tilt.targetY = Math.max(-1, Math.min(1, nx)) * TILT_MAX;
    this.tilt.targetX = Math.max(-1, Math.min(1, ny)) * TILT_MAX;
  }

  // Pointer angle around the ring centre, and how far out it is. Returns null
  // when the pointer sits on the hub, where the angle swings wildly for very
  // little travel.
  grabAngle(event) {
    const rect = this.canvas.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return null;
    const dx = event.clientX - rect.left - this.centre.x;
    const dy = event.clientY - rect.top - this.centre.y;
    if (Math.hypot(dx, dy) < GRAB_MIN_RADIUS) return null;
    return Math.atan2(dy, dx);
  }

  handlePointerDown(event) {
    if (event.button !== 0 || this.disposed || this.contextLost) return;
    const angle = this.grabAngle(event);
    if (angle === null) return;

    this.drag.active = true;
    this.drag.pointerId = event.pointerId;
    this.drag.angle = angle;
    this.drag.time = event.timeStamp || performance.now();
    this.spinVelocity = 0; // Grabbing a moving wheel stops it dead.
    this.canvas.style.cursor = "grabbing";
    // Capture keeps the drag alive past the canvas edge. It throws if the
    // pointer is already gone, which is harmless here.
    try {
      this.canvas.setPointerCapture(event.pointerId);
    } catch (error) { /* not capturable */ }
  }

  handlePointerUp(event) {
    if (!this.drag.active || event.pointerId !== this.drag.pointerId) return;
    this.drag.active = false;
    this.drag.pointerId = null;
    this.canvas.style.cursor = "grab";
    // A running loop carries the throw and springs the ring home. With motion
    // off there is no loop, and starting one would override the reader's
    // preference, so the ring returns to the authored angle in one step.
    if (!this.running && !this.disposed && !this.contextLost) {
      this.spin = 0;
      this.spinVelocity = 0;
      this.draw();
    }
  }

  // Two separate things: the scene leans toward the pointer as it moves over
  // the ring, and — only while held — the ring itself follows the pointer's
  // swing one-to-one in whichever direction it travels.
  handlePointerMove(event) {
    if (event.pointerType !== "touch") this.updateTiltTarget(event);
    if (!this.drag.active || event.pointerId !== this.drag.pointerId) return;

    const angle = this.grabAngle(event);
    if (angle === null) return;

    // Shortest way round, so crossing the -pi/+pi seam does not snap the ring.
    const delta = Math.atan2(Math.sin(angle - this.drag.angle), Math.cos(angle - this.drag.angle));
    const now = event.timeStamp || performance.now();
    const dt = (now - this.drag.time) / 1000;

    this.spin = Math.max(-SPIN_MAX, Math.min(SPIN_MAX, this.spin + delta * SPIN_SIGN));
    if (dt > 0.004) {
      const velocity = (delta * SPIN_SIGN) / dt;
      this.spinVelocity = Math.max(-SPIN_MAX_VELOCITY, Math.min(SPIN_MAX_VELOCITY, velocity));
      this.drag.time = now;
    }
    this.drag.angle = angle;

    // Reduced motion leaves the loop stopped, so paint the drag directly.
    if (!this.running) this.draw();
  }

  // Spring-damper back to the authored angle, carrying whatever velocity the
  // release left behind. Integrated at a fixed step so a long frame (a tab
  // coming back to the foreground) cannot make it explode.
  stepSpin(dt) {
    let remaining = Math.min(dt, 0.25);
    while (remaining > 0) {
      const h = Math.min(SPIN_STEP, remaining);
      remaining -= h;
      this.spinVelocity += (-SPIN_STIFFNESS * this.spin - SPIN_DAMPING * this.spinVelocity) * h;
      this.spin += this.spinVelocity * h;
    }
    if (Math.abs(this.spin) < 1e-4 && Math.abs(this.spinVelocity) < 1e-3) {
      this.spin = 0;
      this.spinVelocity = 0;
    }
  }

  dispose() {
    if (this.disposed) return;
    this.stop();
    this.disposed = true;

    window.removeEventListener("resize", this.boundResize);
    window.removeEventListener("pointermove", this.boundPointerMove);
    document.removeEventListener("mouseout", this.boundMouseOut);
    this.canvas.removeEventListener("pointerdown", this.boundPointerDown);
    this.canvas.removeEventListener("pointerup", this.boundPointerUp);
    this.canvas.removeEventListener("pointercancel", this.boundPointerUp);
    this.canvas.style.cursor = "";
    this.canvas.style.touchAction = "";
    this.canvas.removeEventListener("webglcontextlost", this.boundContextLost);
    this.canvas.removeEventListener("webglcontextrestored", this.boundContextRestored);
    if (this.resizeObserver) this.resizeObserver.disconnect();

    const gl = this.gl;
    if (this.programs) {
      Object.values(this.programs).forEach((entry) => gl.deleteProgram(entry.program));
    }
    if (this.chipBuffers) {
      gl.deleteBuffer(this.chipBuffers.vertex);
      gl.deleteBuffer(this.chipBuffers.index);
    }
    if (this.quadBuffer) gl.deleteBuffer(this.quadBuffer);
    [].concat(this.bloomTargets || [], this.shadowTargets || []).forEach((target) => {
      gl.deleteTexture(target.texture);
      gl.deleteFramebuffer(target.framebuffer);
      if (target.depth) gl.deleteRenderbuffer(target.depth);
    });

    // The context itself is deliberately left alive. A canvas only ever hands
    // out one WebGL context, so losing it here would leave the canvas dead for
    // the remount that Turbo does on every visit (before-cache then load).
  }
}
