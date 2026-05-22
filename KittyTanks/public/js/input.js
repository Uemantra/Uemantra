class Input {
  constructor(canvas) {
    this.canvas = canvas;
    this.keys = {};
    this.mouse = { x: 600, y: 300, down: false, justClicked: false };
    this._prevDown = false;

    document.addEventListener('keydown', e => {
      this.keys[e.code] = true;
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
        e.preventDefault();
      }
    });

    document.addEventListener('keyup', e => {
      this.keys[e.code] = false;
    });

    canvas.addEventListener('mousemove', e => {
      const rect = canvas.getBoundingClientRect();
      const scaleX = canvas.width / rect.width;
      const scaleY = canvas.height / rect.height;
      this.mouse.x = (e.clientX - rect.left) * scaleX;
      this.mouse.y = (e.clientY - rect.top) * scaleY;
    });

    canvas.addEventListener('mousedown', e => {
      if (e.button === 0) {
        this.mouse.down = true;
        e.preventDefault();
      }
    });

    canvas.addEventListener('mouseup', e => {
      if (e.button === 0) {
        this.mouse.down = false;
      }
    });

    canvas.addEventListener('contextmenu', e => e.preventDefault());
  }

  isDown(action) {
    const map = {
      left:   ['ArrowLeft',  'KeyA'],
      right:  ['ArrowRight', 'KeyD'],
      up:     ['ArrowUp',    'KeyW'],
      down:   ['ArrowDown',  'KeyS'],
      fire:   ['Space'],
      endTurn:['KeyE'],
    };
    return (map[action] || [action]).some(k => this.keys[k]);
  }

  justPressed(code) {
    return this.keys[code] === true;
  }

  // Call once per frame to detect rising edge
  update() {
    this.mouse.justClicked = (this.mouse.down && !this._prevDown);
    this._prevDown = this.mouse.down;
  }

  getAimFromKitten(kitten) {
    const dx = this.mouse.x - kitten.x;
    const dy = this.mouse.y - (kitten.y - 20);
    const dist = Math.sqrt(dx * dx + dy * dy);
    const angle = Math.atan2(dy, dx);
    const power = Math.max(10, Math.min(100, dist * 0.55));
    return { angle, power };
  }
}
