const WATER_Y = 560;
const TERRAIN_MIN = 120;
const TERRAIN_MAX = 500;

function seededRNG(seed) {
  let s = seed;
  return () => {
    s = (s + 0x6D2B79F5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

class Terrain {
  constructor(width) {
    this.width = width;
    this.heights = new Float32Array(width);
  }

  generate(seed) {
    const rng = seededRNG(seed);
    const w = this.width;
    const h = this.heights;

    // Layered sine waves for the base shape
    const layers = [
      { amp: 100, freq: 0.0025, phase: rng() * Math.PI * 2 },
      { amp: 50,  freq: 0.006,  phase: rng() * Math.PI * 2 },
      { amp: 25,  freq: 0.013,  phase: rng() * Math.PI * 2 },
      { amp: 12,  freq: 0.028,  phase: rng() * Math.PI * 2 },
    ];

    const baseline = 340;

    for (let x = 0; x < w; x++) {
      let y = baseline;
      for (const l of layers) {
        y += Math.sin(x * l.freq + l.phase) * l.amp;
      }
      h[x] = Math.max(TERRAIN_MIN, Math.min(TERRAIN_MAX, y));
    }

    // Smooth edges so kittens don't spawn in walls
    for (let x = 0; x < 80; x++) {
      const t = x / 80;
      h[x] = h[80] * t + 400 * (1 - t);
    }
    for (let x = w - 80; x < w; x++) {
      const t = (w - x) / 80;
      h[x] = h[w - 81] * t + 400 * (1 - t);
    }

    this._smoothPass(3);
  }

  _smoothPass(passes) {
    for (let p = 0; p < passes; p++) {
      for (let x = 1; x < this.width - 1; x++) {
        this.heights[x] = (this.heights[x - 1] + this.heights[x] * 2 + this.heights[x + 1]) / 4;
      }
    }
  }

  getHeightAt(x) {
    const ix = Math.max(0, Math.min(this.width - 2, Math.floor(x)));
    const t = x - ix;
    return this.heights[ix] * (1 - t) + this.heights[ix + 1] * t;
  }

  carve(cx, cy, radius) {
    const r = Math.ceil(radius);
    const x0 = Math.max(0, cx - r);
    const x1 = Math.min(this.width - 1, cx + r);
    for (let x = x0; x <= x1; x++) {
      const dx = x - cx;
      const inside = radius * radius - dx * dx;
      if (inside < 0) continue;
      const dy = Math.sqrt(inside);
      const bottom = cy + dy;
      if (bottom > this.heights[x]) {
        this.heights[x] = Math.min(bottom, WATER_Y - 5);
      }
    }
    // Re-smooth the carved area edges
    const smooth = 6;
    for (let x = Math.max(1, cx - r - smooth); x <= Math.min(this.width - 2, cx + r + smooth); x++) {
      this.heights[x] = (this.heights[x - 1] * 0.25 + this.heights[x] * 0.5 + this.heights[x + 1] * 0.25);
    }
  }

  draw(ctx) {
    const h = this.heights;
    const w = this.width;
    const bottom = WATER_Y + 10;

    // Main terrain body
    const grad = ctx.createLinearGradient(0, TERRAIN_MIN, 0, WATER_Y);
    grad.addColorStop(0, '#5a8a3a');
    grad.addColorStop(0.08, '#6b5a2a');
    grad.addColorStop(0.5, '#5a4020');
    grad.addColorStop(1, '#3d2810');
    ctx.fillStyle = grad;

    ctx.beginPath();
    ctx.moveTo(0, bottom);
    ctx.lineTo(0, h[0]);
    for (let x = 1; x < w; x++) {
      ctx.lineTo(x, h[x]);
    }
    ctx.lineTo(w, h[w - 1]);
    ctx.lineTo(w, bottom);
    ctx.closePath();
    ctx.fill();

    // Grass strip on top
    ctx.strokeStyle = '#4aaa22';
    ctx.lineWidth = 4;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(0, h[0]);
    for (let x = 1; x < w; x++) {
      ctx.lineTo(x, h[x]);
    }
    ctx.stroke();

    // Grass tufts every ~18px
    ctx.fillStyle = '#3d9915';
    for (let x = 8; x < w - 8; x += 18) {
      const gy = h[x];
      const nx = h[x + 1] || h[x];
      const angle = Math.atan2(nx - gy, 1);
      ctx.save();
      ctx.translate(x, gy);
      ctx.rotate(angle - Math.PI / 2);
      // Three blades
      for (let b = -1; b <= 1; b++) {
        ctx.beginPath();
        ctx.moveTo(b * 3, 0);
        ctx.quadraticCurveTo(b * 5 + b * 2, -6, b * 4, -10);
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = b === 0 ? '#5aCC22' : '#3d9915';
        ctx.stroke();
      }
      ctx.restore();
    }
  }
}
