'use strict';

class Particle {
  constructor(x, y, opts) {
    this.x = x; this.y = y;
    this.vx = opts.vx || 0;
    this.vy = opts.vy || 0;
    this.life = opts.life || 0.5;
    this.maxLife = this.life;
    this.color = opts.color || '#fff';
    this.color2 = opts.color2 || null;
    this.size = opts.size || 2;
    this.gravity = opts.gravity || 0;
    this.friction = opts.friction || 0.92;
    this.type = opts.type || 'square';
    this.text = opts.text || null;
    this.flash = opts.flash || false;
  }

  update(dt) {
    this.vy += this.gravity * dt;
    this.vx *= this.friction;
    this.vy *= this.friction;
    this.x += this.vx * dt;
    this.y += this.vy * dt;
    this.life -= dt;
    return this.life > 0;
  }

  draw(ctx) {
    const t = this.life / this.maxLife;
    ctx.globalAlpha = Math.max(0, t);

    if (this.text) {
      ctx.font = `bold 6px 'Courier New'`;
      ctx.fillStyle = this.color;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(this.text, this.x, this.y);
      ctx.globalAlpha = 1;
      return;
    }

    const s = this.size * (this.flash ? (0.5 + t * 0.5) : t);
    const col = this.color2 ? (t > 0.5 ? this.color : this.color2) : this.color;
    ctx.fillStyle = col;

    if (this.type === 'circle') {
      ctx.beginPath();
      ctx.arc(this.x, this.y, Math.max(0.5, s), 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.fillRect(Math.round(this.x - s/2), Math.round(this.y - s/2), Math.ceil(s), Math.ceil(s));
    }

    ctx.globalAlpha = 1;
  }
}

const Particles = {
  list: [],

  spawn(x, y, opts) {
    this.list.push(new Particle(x, y, opts));
  },

  burst(x, y, count, opts) {
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + rFloat(-0.3, 0.3);
      const speed = rFloat(opts.minSpd || 20, opts.maxSpd || 60);
      this.spawn(x, y, {
        ...opts,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: rFloat(opts.minLife || 0.3, opts.maxLife || 0.7),
        size: rFloat(opts.minSize || 1, opts.maxSize || 3),
      });
    }
  },

  hit(x, y, color) {
    this.burst(x, y, 8, {
      color, color2: '#ffffff',
      minSpd: 25, maxSpd: 80,
      minLife: 0.2, maxLife: 0.5,
      minSize: 1, maxSize: 3,
      gravity: 80, friction: 0.88,
    });
  },

  death(x, y, color) {
    this.burst(x, y, 14, {
      color, color2: '#ffffff',
      minSpd: 30, maxSpd: 100,
      minLife: 0.4, maxLife: 0.9,
      minSize: 1, maxSize: 4,
      gravity: 60, friction: 0.9,
    });
    // Soul float
    this.spawn(x, y, {
      vx: rFloat(-10, 10),
      vy: -60,
      life: 1.0,
      color: '#c0a0ff',
      size: 3,
      gravity: -10,
      friction: 0.99,
      type: 'circle',
    });
  },

  heal(x, y) {
    for (let i = 0; i < 6; i++) {
      this.spawn(x + rFloat(-6,6), y, {
        vx: rFloat(-15,15),
        vy: rFloat(-60,-20),
        life: rFloat(0.5, 0.9),
        color: C.COL.PARTICLE_HEAL,
        size: rFloat(1, 2.5),
        gravity: -20,
        friction: 0.95,
        type: 'circle',
      });
    }
  },

  damage(x, y, amount) {
    this.spawn(x, y - 6, {
      vx: rFloat(-5, 5),
      vy: -40,
      life: 0.8,
      color: C.COL.UI_RED,
      size: 0,
      text: `-${amount}`,
      friction: 0.98,
    });
  },

  goldGain(x, y, amount) {
    this.spawn(x, y - 6, {
      vx: rFloat(-5,5),
      vy: -40,
      life: 0.8,
      color: C.COL.UI_GOLD,
      size: 0,
      text: `+${amount}g`,
      friction: 0.98,
    });
  },

  coin(x, y) {
    this.burst(x, y, 4, {
      color: C.COL.COIN,
      color2: C.COL.COIN_D,
      minSpd: 20, maxSpd: 60,
      minLife: 0.3, maxLife: 0.6,
      minSize: 1, maxSize: 2,
      gravity: 120, friction: 0.9,
    });
  },

  magic(x, y) {
    this.burst(x, y, 10, {
      color: C.COL.PARTICLE_MAGIC,
      color2: '#ffffff',
      minSpd: 20, maxSpd: 70,
      minLife: 0.3, maxLife: 0.8,
      minSize: 1, maxSize: 3,
      gravity: -15, friction: 0.93,
      type: 'circle',
    });
  },

  explosion(x, y) {
    this.burst(x, y, 20, {
      color: '#ff8020',
      color2: '#ffff80',
      minSpd: 30, maxSpd: 120,
      minLife: 0.3, maxLife: 0.8,
      minSize: 1, maxSize: 5,
      gravity: 40, friction: 0.88,
    });
    this.burst(x, y, 6, {
      color: '#ff4010',
      minSpd: 10, maxSpd: 40,
      minLife: 0.5, maxLife: 1.0,
      minSize: 3, maxSize: 7,
      gravity: 20, friction: 0.95,
      type: 'circle',
    });
  },

  poison(x, y) {
    this.burst(x, y, 5, {
      color: '#80ff40',
      color2: '#208000',
      minSpd: 10, maxSpd: 40,
      minLife: 0.4, maxLife: 0.8,
      minSize: 1, maxSize: 2,
      gravity: -20, friction: 0.94,
      type: 'circle',
    });
  },

  update(dt) {
    this.list = this.list.filter(p => p.update(dt));
  },

  draw(ctx) {
    for (const p of this.list) p.draw(ctx);
  },

  clear() { this.list = []; },
};
