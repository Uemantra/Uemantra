'use strict';

// --- Seeded RNG ---
let _rng = 0;
function rngSeed(s) { _rng = s >>> 0; }
function rngNext() {
  _rng ^= _rng << 13; _rng ^= _rng >>> 17; _rng ^= _rng << 5;
  return (_rng >>> 0) / 0xffffffff;
}
function rInt(a, b)  { return Math.floor(rngNext() * (b - a + 1)) + a; }
function rFloat(a,b) { return rngNext() * (b - a) + a; }
function rPick(arr)  { return arr[Math.floor(rngNext() * arr.length)]; }
function rBool(p)    { return rngNext() < (p ?? 0.5); }
function rShuffle(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rngNext() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// --- Math ---
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const lerp  = (a, b, t) => a + (b - a) * t;
const dist  = (x1,y1,x2,y2) => Math.sqrt((x2-x1)**2+(y2-y1)**2);
const dist2 = (x1,y1,x2,y2) => (x2-x1)**2+(y2-y1)**2;
const ang   = (x1,y1,x2,y2) => Math.atan2(y2-y1, x2-x1);
const norm  = (x, y) => { const l = Math.sqrt(x*x+y*y)||1; return {x:x/l,y:y/l}; };
const sign  = (v) => v < 0 ? -1 : v > 0 ? 1 : 0;

function circleRect(cx, cy, cr, rx, ry, rw, rh) {
  const nx = clamp(cx, rx, rx + rw);
  const ny = clamp(cy, ry, ry + rh);
  return dist2(cx, cy, nx, ny) < cr * cr;
}

function circleCircle(x1,y1,r1,x2,y2,r2) {
  return dist2(x1,y1,x2,y2) < (r1+r2)**2;
}

// --- Canvas pixel art helpers ---
function px(ctx, x, y, w, h, color) {
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w || 1, h || 1);
}

function drawPixelRect(ctx, x, y, w, h, color, border) {
  ctx.fillStyle = color;
  ctx.fillRect(x, y, w, h);
  if (border) {
    ctx.fillStyle = border;
    ctx.fillRect(x, y, w, 1);
    ctx.fillRect(x, y, 1, h);
    ctx.fillRect(x+w-1, y, 1, h);
    ctx.fillRect(x, y+h-1, w, 1);
  }
}

function drawText(ctx, text, x, y, size, color, align) {
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  ctx.font = `bold ${size}px 'Courier New', monospace`;
  ctx.fillStyle = color;
  ctx.textAlign = align || 'left';
  ctx.textBaseline = 'top';
  ctx.fillText(text, x, y);
  ctx.restore();
}

function drawTextShadow(ctx, text, x, y, size, color, shadow) {
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  ctx.font = `bold ${size}px 'Courier New', monospace`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = shadow || '#000';
  ctx.fillText(text, x+1, y+1);
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
  ctx.restore();
}

function drawBar(ctx, x, y, w, h, val, max, fg, bg) {
  ctx.fillStyle = bg;
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = fg;
  ctx.fillRect(x, y, Math.round(w * clamp(val/max, 0, 1)), h);
  ctx.fillStyle = 'rgba(255,255,255,0.12)';
  ctx.fillRect(x, y, w, 1);
}

// --- Easing ---
const easeOut = t => 1 - (1-t)**3;
const easeIn  = t => t**3;
const easeInOut = t => t < 0.5 ? 4*t**3 : 1 - (-2*t+2)**3/2;
