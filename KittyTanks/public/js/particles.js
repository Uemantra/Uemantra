class Particle {
  constructor(x, y, vx, vy, color, size, life) {
    this.x = x; this.y = y;
    this.vx = vx; this.vy = vy;
    this.color = color;
    this.size = size || 4;
    this.life = life || 1;
    this.maxLife = this.life;
    this.alive = true;
    this.gravity = 180;
    this.shape = 'circle';
  }

  update(dt) {
    this.x += this.vx * dt;
    this.y += this.vy * dt;
    this.vy += this.gravity * dt;
    this.vx *= 1 - 2 * dt;
    this.life -= dt;
    if (this.life <= 0) this.alive = false;
  }

  draw(ctx) {
    const alpha = Math.max(0, this.life / this.maxLife);
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = this.color;
    if (this.shape === 'square') {
      ctx.fillRect(this.x - this.size / 2, this.y - this.size / 2, this.size, this.size);
    } else {
      ctx.beginPath();
      ctx.arc(this.x, this.y, Math.max(0.5, this.size * alpha), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
}

class TextParticle {
  constructor(x, y, text, color) {
    this.x = x; this.y = y;
    this.text = text; this.color = color || '#fff';
    this.life = 1.8;
    this.maxLife = this.life;
    this.alive = true;
    this.vy = -60;
  }

  update(dt) {
    this.y += this.vy * dt;
    this.vy += 20 * dt;
    this.life -= dt;
    if (this.life <= 0) this.alive = false;
  }

  draw(ctx) {
    const alpha = Math.min(1, this.life / this.maxLife * 2);
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.font = 'bold 18px sans-serif';
    ctx.fillStyle = this.color;
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 3;
    ctx.textAlign = 'center';
    ctx.strokeText(this.text, this.x, this.y);
    ctx.fillText(this.text, this.x, this.y);
    ctx.restore();
  }
}

class ParticleSystem {
  constructor() {
    this.particles = [];
  }

  explode(cx, cy, radius, color) {
    const count = Math.floor(radius * 1.2);
    const colors = [color, '#ffcc00', '#ff6600', '#fff', '#ff4444'];
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = (0.3 + Math.random() * 0.7) * radius * 3;
      const c = colors[Math.floor(Math.random() * colors.length)];
      const size = 2 + Math.random() * 5;
      const p = new Particle(cx, cy,
        Math.cos(angle) * speed,
        Math.sin(angle) * speed - 30,
        c, size, 0.6 + Math.random() * 0.8);
      this.particles.push(p);
    }
    // Smoke puffs
    for (let i = 0; i < 8; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = Math.random() * radius;
      const p = new Particle(cx, cy,
        Math.cos(angle) * speed * 0.5,
        Math.sin(angle) * speed * 0.5 - 60,
        `rgba(120,120,120,0.6)`, 8 + Math.random() * 8, 0.8 + Math.random() * 0.4);
      p.gravity = -20;
      this.particles.push(p);
    }
  }

  confetti(cx, cy, colors) {
    for (let i = 0; i < 20; i++) {
      const angle = (Math.random() - 0.5) * Math.PI * 2;
      const speed = 50 + Math.random() * 150;
      const c = colors[Math.floor(Math.random() * colors.length)];
      const p = new Particle(cx, cy, Math.cos(angle) * speed, Math.sin(angle) * speed - 100, c, 6, 1.2);
      p.shape = 'square';
      p.gravity = 200;
      this.particles.push(p);
    }
  }

  addText(x, y, text, color) {
    this.particles.push(new TextParticle(x, y, text, color));
  }

  dust(cx, cy, count) {
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 20 + Math.random() * 60;
      const p = new Particle(cx, cy,
        Math.cos(angle) * speed, Math.sin(angle) * speed,
        '#c8a870', 3 + Math.random() * 3, 0.5 + Math.random() * 0.3);
      p.gravity = 100;
      this.particles.push(p);
    }
  }

  update(dt) {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      this.particles[i].update(dt);
      if (!this.particles[i].alive) this.particles.splice(i, 1);
    }
  }

  draw(ctx) {
    this.particles.forEach(p => p.draw(ctx));
  }
}
