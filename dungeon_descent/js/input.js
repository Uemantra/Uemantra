'use strict';

const Input = {
  keys: new Set(),
  pressed: new Set(),
  released: new Set(),
  mouse: { x: C.VW/2, y: C.VH/2, left: false, right: false, leftDown: false, rightDown: false },
  touch: { dx: 0, dy: 0, sword: false, shoot: false, block: false },

  init(canvas) {
    window.addEventListener('keydown', e => {
      if (!this.keys.has(e.code)) this.pressed.add(e.code);
      this.keys.add(e.code);
      if (['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.code))
        e.preventDefault();
    });
    window.addEventListener('keyup', e => {
      this.keys.delete(e.code);
      this.released.add(e.code);
    });
    canvas.addEventListener('mousemove', e => {
      const r = canvas.getBoundingClientRect();
      this.mouse.x = (e.clientX - r.left) / C.S;
      this.mouse.y = (e.clientY - r.top) / C.S;
    });
    canvas.addEventListener('mousedown', e => {
      if (e.button === 0) { this.mouse.left = true;  this.mouse.leftDown = true; }
      if (e.button === 2) { this.mouse.right = true; this.mouse.rightDown = true; }
      e.preventDefault();
    });
    canvas.addEventListener('mouseup', e => {
      if (e.button === 0) this.mouse.left = false;
      if (e.button === 2) this.mouse.right = false;
    });
    canvas.addEventListener('contextmenu', e => e.preventDefault());

    // Touch controls
    this._bindTouchBtn('btn-up',    () => { this.touch.dy = -1; }, () => { if (this.touch.dy < 0) this.touch.dy = 0; });
    this._bindTouchBtn('btn-down',  () => { this.touch.dy =  1; }, () => { if (this.touch.dy > 0) this.touch.dy = 0; });
    this._bindTouchBtn('btn-left',  () => { this.touch.dx = -1; }, () => { if (this.touch.dx < 0) this.touch.dx = 0; });
    this._bindTouchBtn('btn-right', () => { this.touch.dx =  1; }, () => { if (this.touch.dx > 0) this.touch.dx = 0; });
    this._bindTouchBtn('btn-sword', () => { this.touch.sword = true; }, () => { this.touch.sword = false; });
    this._bindTouchBtn('btn-shoot', () => { this.touch.shoot = true; }, () => { this.touch.shoot = false; });
    this._bindTouchBtn('btn-block', () => { this.touch.block = true; }, () => { this.touch.block = false; });
  },

  _bindTouchBtn(id, onDown, onUp) {
    const el = document.getElementById(id);
    if (!el) return;
    el.addEventListener('touchstart', e => { e.preventDefault(); onDown(); }, { passive: false });
    el.addEventListener('touchend',   e => { e.preventDefault(); onUp(); },   { passive: false });
  },

  update() {
    this.pressed.clear();
    this.released.clear();
    this.mouse.leftDown = false;
    this.mouse.rightDown = false;
  },

  down(k)    { return this.keys.has(k); },
  just(k)    { return this.pressed.has(k); },
  justUp(k)  { return this.released.has(k); },

  moveX() {
    if (this.touch.dx !== 0) return this.touch.dx;
    return (this.down('KeyD') || this.down('ArrowRight') ? 1 : 0) -
           (this.down('KeyA') || this.down('ArrowLeft')  ? 1 : 0);
  },
  moveY() {
    if (this.touch.dy !== 0) return this.touch.dy;
    return (this.down('KeyS') || this.down('ArrowDown')  ? 1 : 0) -
           (this.down('KeyW') || this.down('ArrowUp')    ? 1 : 0);
  },
  wantSword() {
    return this.touch.sword || this.mouse.leftDown || this.just('KeyZ') || this.just('KeyJ');
  },
  wantShoot() {
    return this.touch.shoot || this.mouse.rightDown || this.just('KeyX') || this.just('KeyK');
  },
  wantBlock() {
    return this.touch.block || this.down('Space') || this.down('ShiftLeft') || this.down('ShiftRight');
  },
  wantConfirm() {
    return this.just('Space') || this.just('Enter') || this.just('KeyE') || this.mouse.leftDown;
  },
  wantPause() {
    return this.just('Escape') || this.just('KeyP');
  },
};
