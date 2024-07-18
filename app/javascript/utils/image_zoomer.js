export default class ImageZoomer {
  constructor(imgUrl) {
    this.zoomVal = 0;
    this.canvas = document.getElementsByTagName('canvas')[0];
    this.image = new Image();
    this.ctx = this.canvas.getContext('2d');
    this.image.src = imgUrl;
    this.lastX = this.canvas.width / 2;
    this.lastY = this.canvas.height / 2;
    this.trackTransforms(this.ctx);
    this.redraw();
    this.bindEvents();
  }

  changeImage(newUrl) {
    this.image.src = newUrl;
    this.redraw();
  }

  transform(x, y) {
    this.lastX = x;
    this.lastY = y;
  }

  savePosition(x, y) {
    const posX =  document.querySelector(".pos-x");
    const posY = document.querySelector(".pos-y")
    if(posX)
      posX.value = x;
    if(posY)
      posY.value = y;
  }

  zoom(clicks) {
    this.zoomVal += clicks;
    const inputZoom = document.querySelector(".zoom")

    if(inputZoom)
      inputZoom.value = this.zoomVal;

    const scaleFactor = 1.1;
    const pt = this.ctx.transformedPoint(this.lastX, this.lastY);
    this.ctx.translate(pt.x, pt.y);
    const factor = Math.pow(scaleFactor, clicks);
    this.ctx.scale(factor, factor);
    this.ctx.translate(-pt.x, -pt.y);
    this.redraw();
  }

  handleScroll(evt) {
    const delta = evt.wheelDelta ? evt.wheelDelta / 40 : evt.detail ? -evt.detail : 0;
    if (delta) {
      this.zoom(delta);
    }
    evt.preventDefault();
  }

  bindEvents() {
    let dragStart;
    let dragged;
    this.canvas.addEventListener('DOMMouseScroll', this.handleScroll.bind(this), false);
    this.canvas.addEventListener('mousewheel', this.handleScroll.bind(this), false);
    this.canvas.addEventListener('mousedown', (evt) => {
      document.body.style.userSelect = 'none';
      this.lastX = evt.offsetX || evt.pageX - this.canvas.offsetLeft;
      this.lastY = evt.offsetY || evt.pageY - this.canvas.offsetTop;
      this.savePosition(this.lastX, this.lastY);
      dragStart = this.ctx.transformedPoint(this.lastX, this.lastY);
      dragged = false;
    }, false);
    this.canvas.addEventListener('mousemove', (evt) => {
      const lastX = evt.offsetX || evt.pageX - this.canvas.offsetLeft;
      const lastY = evt.offsetY || evt.pageY - this.canvas.offsetTop;
      dragged = true;
      if (dragStart) {
        const pt = this.ctx.transformedPoint(lastX, lastY);
        this.ctx.translate(pt.x - dragStart.x, pt.y - dragStart.y);
        this.redraw();
      }
    }, false);
    this.canvas.addEventListener('mouseup', () => {
      document.body.style.userSelect = 'auto';
      dragStart = null;
      if (!dragged) {
        this.zoom(event.shiftKey ? -1 : 1);
      }
    }, false);
  }

  redraw() {
    const p1 = this.ctx.transformedPoint(0, 0);
    const p2 = this.ctx.transformedPoint(this.canvas.width, this.canvas.height);
    this.ctx.save();
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.restore();
    this.ctx.drawImage(this.image, 0, 0);
  }

  trackTransforms(ctx) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    let xform = svg.createSVGMatrix();
    ctx.getTransform = () => xform;
    const savedTransforms = [];
    const save = ctx.save;
    ctx.save = () => {
      savedTransforms.push(xform.translate(0, 0));
      save.call(ctx);
    };
    const restore = ctx.restore;
    ctx.restore = () => {
      xform = savedTransforms.pop();
      restore.call(ctx);
    };
    const scale = ctx.scale;
    ctx.scale = (sx, sy) => {
      xform = xform.scaleNonUniform(sx, sy);
      scale.call(ctx, sx, sy);
    };
    const rotate = ctx.rotate;
    ctx.rotate = (radians) => {
      xform = xform.rotate(radians * 180 / Math.PI);
      rotate.call(ctx, radians);
    };
    const translate = ctx.translate;
    ctx.translate = (dx, dy) => {
      xform = xform.translate(dx, dy);
      translate.call(ctx, dx, dy);
    };
    const transform = ctx.transform;
    ctx.transform = (a, b, c, d, e, f) => {
      const m2 = svg.createSVGMatrix();
      m2.a = a;
      m2.b = b;
      m2.c = c;
      m2.d = d;
      m2.e = e;
      m2.f = f;
      xform = xform.multiply(m2);
      transform.call(ctx, a, b, c, d, e, f);
    };
    const setTransform = ctx.setTransform;
    ctx.setTransform = (a, b, c, d, e, f) => {
      xform.a = a;
      xform.b = b;
      xform.c = c;
      xform.d = d;
      xform.e = e;
      xform.f = f;
      setTransform.call(ctx, a, b, c, d, e, f);
    };
    const pt = svg.createSVGPoint();
    ctx.transformedPoint = (x, y) => {
      pt.x = x;
      pt.y = y;
      return pt.matrixTransform(xform.inverse());
    };
  }
}
