const GRAVITY_BASE = 280;

class Projectile {
  constructor(x, y, angle, power, weapon, wind, terrain, targetKitten) {
    this.x = x;
    this.y = y;
    this.weapon = weapon;
    this.terrain = terrain;
    this.targetKitten = targetKitten; // for homing
    this.wind = wind;
    this.bounceCount = 0;
    this.alive = true;
    this.trail = [];
    this.age = 0;

    const spd = power * 7.5 * weapon.speed;
    this.vx = Math.cos(angle) * spd;
    this.vy = Math.sin(angle) * spd;
    this.gravity = weapon.gravity || GRAVITY_BASE;
  }

  update(dt, terrain, kittens) {
    if (!this.alive) return null;
    this.age += dt;

    // Trail
    this.trail.push({ x: this.x, y: this.y, age: 0 });
    if (this.trail.length > 18) this.trail.shift();
    this.trail.forEach(t => t.age += dt);

    // Homing logic
    if (this.weapon.type === 'homing' && this.targetKitten && this.age > 0.4) {
      const tk = this.targetKitten;
      const dx = tk.x - this.x;
      const dy = (tk.y - 20) - this.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist > 30) {
        const tx = (dx / dist) * 220;
        const ty = (dy / dist) * 220;
        this.vx += (tx - this.vx) * 1.8 * dt;
        this.vy += (ty - this.vy) * 1.8 * dt;
      }
    }

    // Physics
    if (this.weapon.type !== 'homing') {
      this.vx += this.wind * 10 * dt;
    }
    this.vy += this.gravity * dt;
    this.x += this.vx * dt;
    this.y += this.vy * dt;

    // Out of bounds
    if (this.x < -50 || this.x > terrain.width + 50 || this.y > WATER_Y + 20) {
      this.alive = false;
      return { type: 'oob', x: this.x, y: this.y };
    }

    // Terrain collision
    const tx = Math.floor(this.x);
    if (tx >= 0 && tx < terrain.width) {
      const groundY = terrain.getHeightAt(this.x);
      if (this.y >= groundY) {
        if (this.bounceCount < (this.weapon.bounces || 0)) {
          // Bounce
          this.y = groundY - 1;
          this.vy *= -0.55;
          this.vx *= 0.8;
          this.bounceCount++;
        } else {
          this.alive = false;
          return { type: 'terrain', x: this.x, y: groundY };
        }
      }
    }

    // Kitten collision
    for (const kitten of kittens) {
      if (!kitten) continue;
      const dx = kitten.x - this.x;
      const dy = (kitten.y - 20) - this.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 20) {
        this.alive = false;
        return { type: 'kitten', x: this.x, y: this.y, kitten };
      }
    }

    return null;
  }

  draw(ctx) {
    // Trail
    const tw = this.weapon.trailColor || 'rgba(255,255,255,0.3)';
    for (let i = 0; i < this.trail.length; i++) {
      const t = this.trail[i];
      const alpha = (i / this.trail.length) * 0.6;
      const r = (i / this.trail.length) * 4;
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = tw;
      ctx.beginPath();
      ctx.arc(t.x, t.y, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // Projectile shape
    if (this.weapon.drawProjectile) {
      this.weapon.drawProjectile(ctx, this.x, this.y, this.vx, this.vy);
    } else {
      ctx.fillStyle = this.weapon.color;
      ctx.beginPath();
      ctx.arc(this.x, this.y, 6, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

class LaserBeam {
  constructor(kx, ky, weapon) {
    this.x = kx;
    this.y = ky;
    this.weapon = weapon;
    this.targetX = kx;
    this.targetY = ky;
    this.timeLeft = weapon.duration;
    this.alive = true;
    this.damageAccum = 0;
    this.tickTime = 0;
  }

  update(dt, mouseX, mouseY, terrain, kittens) {
    this.targetX = mouseX;
    this.targetY = mouseY;
    this.timeLeft -= dt;
    this.tickTime += dt;

    if (this.timeLeft <= 0) {
      this.alive = false;
      return { type: 'done', damage: 0, targetId: null };
    }

    // Check if laser hits a kitten along the beam
    let result = null;
    if (this.tickTime >= 0.12) {
      this.tickTime = 0;
      // Sample points along the laser ray
      const dx = this.targetX - this.x;
      const dy = this.targetY - this.y;
      const len = Math.sqrt(dx * dx + dy * dy);
      if (len > 0) {
        const steps = Math.ceil(len / 8);
        for (let s = 1; s <= steps; s++) {
          const t = s / steps;
          const px = this.x + dx * t;
          const py = this.y + dy * t;
          // Hit terrain?
          const groundY = terrain.getHeightAt(px);
          if (py >= groundY) break;
          // Hit kitten?
          for (const k of kittens) {
            if (!k) continue;
            const kd = Math.sqrt((k.x - px) ** 2 + ((k.y - 20) - py) ** 2);
            if (kd < 18) {
              result = { type: 'laser_hit', kitten: k, damage: this.weapon.damage };
            }
          }
        }
      }
    }

    return result;
  }

  draw(ctx) {
    if (!this.alive) return;
    const alpha = Math.min(1, this.timeLeft);

    // Outer glow
    ctx.save();
    ctx.globalAlpha = alpha * 0.3;
    ctx.strokeStyle = '#ff4444';
    ctx.lineWidth = 10;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(this.x, this.y);
    ctx.lineTo(this.targetX, this.targetY);
    ctx.stroke();

    // Core
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = '#ff0000';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(this.x, this.y);
    ctx.lineTo(this.targetX, this.targetY);
    ctx.stroke();

    // Bright core
    ctx.strokeStyle = '#ffaaaa';
    ctx.lineWidth = 1;
    ctx.stroke();

    // Dot at end
    ctx.fillStyle = '#ff0000';
    ctx.beginPath();
    ctx.arc(this.targetX, this.targetY, 5, 0, Math.PI * 2);
    ctx.fill();

    // Timer ring
    const pct = this.timeLeft / this.weapon.duration;
    ctx.globalAlpha = 0.7;
    ctx.strokeStyle = '#ff4444';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(this.x, this.y, 14, -Math.PI / 2, -Math.PI / 2 + pct * Math.PI * 2);
    ctx.stroke();

    ctx.restore();
  }
}
