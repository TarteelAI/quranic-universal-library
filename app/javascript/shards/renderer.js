import * as THREE from "three";
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/examples/jsm/postprocessing/OutputPass.js";

import { SHARD_SCENE as DATA } from "./scene_data";

const RING_RPM = 4; // clockwise revolutions per minute
const MAX_TILT = 0.26; // radians of mouse-follow tilt

// Fraction of the container's shorter side the ring spans. Small panels (the
// devise hero is only 30vh tall on phones) get a tighter crop so the ring still
// reads at a glance.
const FILL_LARGE = 0.92;
const FILL_SMALL = 0.99;
const SMALL_CANVAS = 380;

// Fallback starting distance for the framing search (the authored camera sits
// at roughly this distance from the ring).
const DEFAULT_DISTANCE = 735;

export default class ShardRing {
  constructor(canvas, container) {
    this.canvas = canvas;
    this.container = container || canvas.parentElement;
    this.disposed = false;
    this.running = false;
    this.frame = null;
    this.target = { x: 0, y: 0 };
    this.current = { x: 0, y: 0 };

    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.35;

    this.scene = new THREE.Scene();

    this.buildEnvironment();
    this.buildCamera();
    this.buildSamplePoints();
    this.buildChips();
    this.buildLights();
    this.buildComposer();

    this.boundResize = () => this.resize();
    this.boundPointerMove = (event) => this.handlePointerMove(event);
    window.addEventListener("resize", this.boundResize);
    window.addEventListener("pointermove", this.boundPointerMove);

    // The hero column can change size without the window doing so (layout
    // shifts, the devise modal), so track the canvas box directly too.
    if ("ResizeObserver" in window) {
      this.resizeObserver = new ResizeObserver(this.boundResize);
      this.resizeObserver.observe(canvas);
    }

    this.clock = new THREE.Clock();
    this.resize();
  }

  // Bright studio environment. On near-mirror metal the body color is the
  // reflection of this env, so the palette here (not the lights) sets the chip
  // color: mixed lime + yellow-green + white patches over a warm green base.
  buildEnvironment() {
    const pmrem = new THREE.PMREMGenerator(this.renderer);
    const env = new THREE.Scene();
    env.add(
      new THREE.Mesh(
        new THREE.SphereGeometry(60, 16, 16),
        new THREE.MeshBasicMaterial({ color: 0x16240a, side: THREE.BackSide }),
      ),
    );

    const glow = (color, x, y, z, size) => {
      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(size, size, 1),
        new THREE.MeshBasicMaterial({ color }),
      );
      mesh.position.set(x, y, z);
      env.add(mesh);
    };

    glow(0xfff7d6, 20, 35, 30, 44); // warm white hotspot
    glow(0xd4ff8a, -30, 25, 20, 40); // soft lime
    glow(0xc8ff5a, 30, -25, 25, 36); // bright lime
    glow(0xa8e04a, -25, -30, -30, 34); // yellow-green
    glow(0x6fae33, 0, 40, -35, 30); // deeper yellow-green

    this.envTarget = pmrem.fromScene(env);
    this.scene.environment = this.envTarget.texture;
    pmrem.dispose();
    env.traverse((object) => {
      if (object.isMesh) {
        object.geometry.dispose();
        object.material.dispose();
      }
    });
  }

  buildCamera() {
    this.camera = new THREE.PerspectiveCamera(45, 1, 70, 100000);
    new THREE.Matrix4()
      .fromArray(DATA.cam)
      .decompose(this.camera.position, this.camera.quaternion, new THREE.Vector3());
    this.camera.updateMatrixWorld();
    // Keep the authored viewing angle but re-derive the distance per aspect
    // ratio in resize(), so the ring frames itself in any container shape.
    this.cameraDirection = this.camera.position.clone().normalize();
  }

  // Every shard vertex in world space. resize() projects these to find the
  // ring's true on-screen extent — the authored camera aims at the origin, so
  // the spin (a rotation about the view axis) turns the image about the screen
  // centre and leaves each vertex's distance from that centre unchanged. That
  // makes both the outer radius and the hole stable while the ring turns.
  buildSamplePoints() {
    const parent = new THREE.Matrix4().fromArray(DATA.parent);
    const matrix = new THREE.Matrix4();
    const points = [];

    DATA.mats.forEach((array) => {
      matrix.fromArray(array).premultiply(parent);
      for (let i = 0; i < DATA.pos.length; i += 3) {
        points.push(
          new THREE.Vector3(DATA.pos[i], DATA.pos[i + 1], DATA.pos[i + 2]).applyMatrix4(matrix),
        );
      }
    });

    this.samplePoints = points;
  }

  // Distance at which the ring spans `fill` of the shorter side. The projected
  // radius is very nearly inversely proportional to distance, so a couple of
  // correction passes converge.
  fitDistance(fill) {
    const projected = new THREE.Vector3();
    // Seed from the authored camera distance; it is already the right order of
    // magnitude, so a few passes land on the exact fit.
    let distance = this.camera.position.length();
    if (!(distance > 1)) distance = DEFAULT_DISTANCE;

    for (let pass = 0; pass < 6; pass += 1) {
      this.camera.position.copy(this.cameraDirection).multiplyScalar(distance);
      this.camera.updateMatrixWorld();

      let outer = 0;
      this.samplePoints.forEach((point) => {
        projected.copy(point).project(this.camera);
        // Measure in "half-height" units: NDC is -1..1 on both axes, so scaling
        // x by the aspect ratio makes a radius here match pixels on screen.
        const radius = Math.hypot(projected.x * this.camera.aspect, projected.y);
        if (radius > outer) outer = radius;
      });

      // In those units the frame reaches 1 vertically but `aspect` horizontally,
      // so the ring has to clear the smaller of the two or it overflows the
      // narrow axis as it turns.
      const limit = fill * Math.min(1, this.camera.aspect);
      const correction = outer / limit;
      if (Math.abs(correction - 1) < 0.002) break;
      distance *= correction;
    }

    return distance;
  }

  // Publish the ring's centre so the QUL lockup can sit on it. The authored
  // camera aims at the origin, so the ring turns about this point on screen.
  publishRingCentre(width, height) {
    if (!this.container) return;

    const centre = new THREE.Vector3().project(this.camera);
    const style = this.container.style;
    style.setProperty("--qul-ring-cx", `${((centre.x * 0.5 + 0.5) * width).toFixed(1)}px`);
    style.setProperty("--qul-ring-cy", `${((-centre.y * 0.5 + 0.5) * height).toFixed(1)}px`);
    this.container.dataset.qulRingReady = "true";
  }

  buildChips() {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(new Float32Array(DATA.pos), 3));
    geometry.setAttribute("normal", new THREE.BufferAttribute(new Float32Array(DATA.nor), 3));
    geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(DATA.idx), 1));

    // Green iridescent metal: polished green-chrome body, white specular
    // hotspots, chromatic edge glints. Per-chip lightness variation comes from
    // the lighting, not a painted gradient.
    const material = new THREE.MeshPhysicalMaterial({
      color: 0x5aa83a,
      metalness: 0.95,
      roughness: 0.13,
      iridescence: 0.55,
      iridescenceIOR: 1.35,
      iridescenceThicknessRange: [120, 320],
      clearcoat: 1.0,
      clearcoatRoughness: 0.05,
      reflectivity: 0.75,
      envMapIntensity: 1.15,
      side: THREE.DoubleSide,
    });

    this.geometry = geometry;
    this.material = material;

    const instances = new THREE.InstancedMesh(geometry, material, DATA.mats.length);
    const matrix = new THREE.Matrix4();
    DATA.mats.forEach((array, index) => instances.setMatrixAt(index, matrix.fromArray(array)));
    instances.instanceMatrix.needsUpdate = true;
    // three.js culls an InstancedMesh against the single shard's bounding
    // sphere, which ignores where the 16 instances actually sit — the ring can
    // drop out of view entirely. There is only one mesh, so skip culling.
    instances.frustumCulled = false;
    this.instances = instances;

    this.chips = new THREE.Group();
    this.chips.applyMatrix4(new THREE.Matrix4().fromArray(DATA.parent));
    this.chips.add(instances);

    this.rig = new THREE.Group();
    this.rig.add(this.chips);
    this.scene.add(this.rig);

    // Clockwise-on-screen spin: rotate the chips about the camera view axis, so
    // the direction reads correctly regardless of the ring's 3D tilt.
    this.viewAxis = new THREE.Vector3();
    this.camera.getWorldDirection(this.viewAxis);
    this.baseChipQuaternion = this.chips.quaternion.clone();
    this.spinQuaternion = new THREE.Quaternion();
    this.ringRate = (RING_RPM * Math.PI * 2) / 60;
  }

  buildLights() {
    const spot = (array, color, intensity, distance, angleDeg, penumbra) => {
      const light = new THREE.SpotLight(
        color,
        intensity,
        distance,
        THREE.MathUtils.degToRad(angleDeg),
        penumbra,
        1.0,
      );
      new THREE.Matrix4()
        .fromArray(array)
        .decompose(light.position, light.quaternion, new THREE.Vector3());
      light.target.position.set(0, 0, 0);
      this.scene.add(light.target);
      return light;
    };

    this.scene.add(spot(DATA.s2, 0x8d3ae2, 6.5, 7010, 30, 0.0)); // purple
    this.scene.add(spot(DATA.s3, 0xf5e000, 9.0, 8628, 30, 0.2)); // yellow

    const directional = new THREE.DirectionalLight(0xffffff, 1.6);
    directional.position.set(200, 300, 300);
    this.scene.add(directional);

    // Camera-side fill lights the faces pointing at the viewer. Slightly warm
    // (pale lime-white) so highlights lean yellow-green rather than neutral.
    const fill = new THREE.DirectionalLight(0xf2ffcf, 3.0);
    this.camera.getWorldPosition(fill.position);
    fill.target.position.set(0, 0, 0);
    this.scene.add(fill.target);
    this.scene.add(fill);

    this.scene.add(new THREE.AmbientLight(0xffffff, 0.6));

    const point = new THREE.PointLight(0xffffff, 2.5, 0, 0.0);
    this.camera.getWorldPosition(point.position);
    this.scene.add(point);

    this.cameraLights = [fill, point];
  }

  buildComposer() {
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.6, 0.45, 0.85);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
  }

  size() {
    const width = this.canvas.clientWidth || 1;
    const height = this.canvas.clientHeight || 1;
    return { width, height };
  }

  resize() {
    if (this.disposed) return;

    const { width, height } = this.size();

    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();

    const fill = Math.min(width, height) < SMALL_CANVAS ? FILL_SMALL : FILL_LARGE;
    // Resolve the distance before touching camera.position: fitDistance() reads
    // the current position as its starting guess.
    const distance = this.fitDistance(fill);
    this.camera.position.copy(this.cameraDirection).multiplyScalar(distance);
    this.camera.updateMatrixWorld();

    this.cameraLights.forEach((light) => this.camera.getWorldPosition(light.position));
    this.publishRingCentre(width, height);

    this.renderer.setSize(width, height, false);
    this.composer.setSize(width, height);

    // When motion is off nothing else will redraw, so repaint at the new size.
    if (!this.running && this.hasRendered) this.renderStill();
  }

  handlePointerMove(event) {
    const rect = this.canvas.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const nx = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    const ny = ((event.clientY - rect.top) / rect.height) * 2 - 1;
    this.target.y = THREE.MathUtils.clamp(nx, -1, 1) * MAX_TILT;
    this.target.x = THREE.MathUtils.clamp(ny, -1, 1) * MAX_TILT;
  }

  start() {
    if (this.running || this.disposed) return;
    this.running = true;
    this.clock.getDelta(); // drop time accumulated while paused
    this.loop();
  }

  stop() {
    this.running = false;
    if (this.frame) {
      cancelAnimationFrame(this.frame);
      this.frame = null;
    }
  }

  loop() {
    if (!this.running || this.disposed) return;
    this.frame = requestAnimationFrame(() => this.loop());

    this.angle = (this.angle || 0) + this.clock.getDelta() * this.ringRate;
    this.spinQuaternion.setFromAxisAngle(this.viewAxis, this.angle);
    this.chips.quaternion.copy(this.spinQuaternion).multiply(this.baseChipQuaternion);

    const dx = this.target.x - this.current.x;
    const dy = this.target.y - this.current.y;
    if (Math.abs(dx) > 1e-4 || Math.abs(dy) > 1e-4) {
      this.current.x += dx * 0.06;
      this.current.y += dy * 0.06;
      this.rig.rotation.x = this.current.x;
      this.rig.rotation.y = this.current.y;
    }

    this.hasRendered = true;
    this.composer.render();
  }

  // Draw a single frame — used when motion is disabled (prefers-reduced-motion)
  // so the ring still shows, just static.
  renderStill() {
    if (this.disposed) return;
    this.hasRendered = true;
    this.composer.render();
  }

  dispose() {
    if (this.disposed) return;
    this.stop();
    this.disposed = true;

    window.removeEventListener("resize", this.boundResize);
    window.removeEventListener("pointermove", this.boundPointerMove);
    if (this.resizeObserver) this.resizeObserver.disconnect();

    this.composer.dispose();
    this.geometry.dispose();
    this.material.dispose();
    this.instances.dispose();
    this.envTarget.dispose();
    this.renderer.dispose();
  }
}
