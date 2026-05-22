const WEAPONS = {
  yarn: {
    id: 'yarn',
    name: 'Yarn Ball',
    icon: '🧶',
    color: '#ff6b9d',
    trailColor: 'rgba(255,107,157,0.5)',
    damage: 28,
    radius: 42,
    bounces: 1,
    speed: 1.0,
    gravity: 280,
    type: 'projectile',
    description: 'Bounces once before exploding!',
    drawProjectile(ctx, x, y, vx, vy) {
      const r = 7;
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(Math.atan2(vy, vx) + Date.now() * 0.01);
      // Ball
      ctx.fillStyle = '#ff6b9d';
      ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();
      // Yarn lines
      ctx.strokeStyle = '#ff99cc';
      ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(-r, 0); ctx.lineTo(r, 0); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, -r); ctx.lineTo(0, r); ctx.stroke();
      ctx.beginPath(); ctx.arc(0, 0, r * 0.6, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
    }
  },

  hairball: {
    id: 'hairball',
    name: 'Hairball Bomb',
    icon: '🤮',
    color: '#8bc34a',
    trailColor: 'rgba(139,195,74,0.4)',
    damage: 48,
    radius: 62,
    bounces: 0,
    speed: 0.72,
    gravity: 320,
    type: 'projectile',
    description: 'Disgusting AND deadly. Big boom!',
    drawProjectile(ctx, x, y, vx, vy) {
      ctx.save();
      ctx.translate(x, y);
      const spin = Date.now() * 0.008;
      ctx.rotate(spin);
      // Lumpy blob
      ctx.fillStyle = '#6a8c20';
      ctx.beginPath();
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        const r = 8 + Math.sin(a * 3) * 3;
        i === 0 ? ctx.moveTo(Math.cos(a)*r, Math.sin(a)*r)
                : ctx.lineTo(Math.cos(a)*r, Math.sin(a)*r);
      }
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#9bc840';
      ctx.beginPath(); ctx.arc(-2, -2, 4, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  },

  catnip: {
    id: 'catnip',
    name: 'Catnip Cloud',
    icon: '🌿',
    color: '#66bb6a',
    trailColor: 'rgba(102,187,106,0.4)',
    damage: 12,
    radius: 68,
    bounces: 0,
    speed: 0.85,
    gravity: 260,
    type: 'projectile',
    effect: 'confused',
    description: 'Reverses opponent controls for a turn!',
    drawProjectile(ctx, x, y, vx, vy) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(Date.now() * 0.006);
      // Leaf shape
      ctx.fillStyle = '#4caf50';
      ctx.beginPath();
      ctx.ellipse(0, -6, 5, 10, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#81c784';
      ctx.beginPath();
      ctx.ellipse(5, 2, 5, 8, Math.PI / 3, 0, Math.PI * 2);
      ctx.fill();
      // Sparkle
      ctx.fillStyle = '#fff';
      ctx.globalAlpha = 0.6;
      ctx.beginPath(); ctx.arc(-4, -8, 2, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  },

  missile: {
    id: 'missile',
    name: 'Hiss Missile',
    icon: '🚀',
    color: '#ff5722',
    trailColor: 'rgba(255,87,34,0.5)',
    damage: 38,
    radius: 48,
    bounces: 0,
    speed: 0.62,
    gravity: 80,
    type: 'homing',
    description: 'Seeks the enemy with burning hatred!',
    drawProjectile(ctx, x, y, vx, vy) {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(Math.atan2(vy, vx));
      // Missile body
      ctx.fillStyle = '#ff5722';
      ctx.beginPath();
      ctx.moveTo(14, 0);
      ctx.lineTo(-6, -5);
      ctx.lineTo(-6, 5);
      ctx.closePath();
      ctx.fill();
      // Fins
      ctx.fillStyle = '#bf360c';
      ctx.beginPath(); ctx.moveTo(-6,-5); ctx.lineTo(-12,-12); ctx.lineTo(-6,0); ctx.fill();
      ctx.beginPath(); ctx.moveTo(-6,5); ctx.lineTo(-12,12); ctx.lineTo(-6,0); ctx.fill();
      // Flame
      ctx.fillStyle = '#ffcc00';
      ctx.beginPath(); ctx.arc(-8, 0, 5, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#ff6600';
      ctx.beginPath(); ctx.arc(-10, 0, 3, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  },

  zoomies: {
    id: 'zoomies',
    name: 'Midnight Zoomies',
    icon: '⚡',
    color: '#ffeb3b',
    trailColor: 'rgba(255,235,59,0.5)',
    damage: 22,
    radius: 36,
    bounces: 0,
    speed: 1.25,
    gravity: 300,
    type: 'scatter',
    count: 5,
    description: '5 random projectiles — pure chaos!',
    drawProjectile(ctx, x, y, vx, vy) {
      ctx.save();
      ctx.translate(x, y);
      ctx.fillStyle = '#ffeb3b';
      ctx.strokeStyle = '#ff6600';
      ctx.lineWidth = 2;
      ctx.beginPath();
      // Lightning bolt
      ctx.moveTo(4, -8);
      ctx.lineTo(-2, 0);
      ctx.lineTo(2, 0);
      ctx.lineTo(-4, 8);
      ctx.lineTo(2, 2);
      ctx.lineTo(-1, 2);
      ctx.lineTo(4, -8);
      ctx.fill(); ctx.stroke();
      ctx.restore();
    }
  },

  laser: {
    id: 'laser',
    name: 'Laser Pointer',
    icon: '🔴',
    color: '#f44336',
    trailColor: 'rgba(244,67,54,0.4)',
    damage: 9, // per second
    radius: 0,
    bounces: 0,
    speed: 0,
    gravity: 0,
    type: 'laser',
    duration: 3.5,
    description: 'Guide it with your mouse for 3.5s!',
    drawProjectile(ctx, x, y) {
      ctx.save();
      ctx.fillStyle = '#f44336';
      ctx.beginPath(); ctx.arc(x, y, 5, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#ff9999';
      ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  },

  fish: {
    id: 'fish',
    name: 'Dead Fish Slap',
    icon: '🐟',
    color: '#78909c',
    trailColor: 'rgba(120,144,156,0.3)',
    damage: 58,
    radius: 0,
    bounces: 0,
    speed: 1.25,
    gravity: 60,
    type: 'melee',
    range: 170,
    knockback: 420,
    description: 'Extreme damage! Must be within 170px.',
    drawProjectile(ctx, x, y, vx) {
      ctx.save();
      ctx.translate(x, y);
      if (vx < 0) ctx.scale(-1, 1);
      ctx.fillStyle = '#78909c';
      ctx.beginPath();
      ctx.ellipse(0, 0, 14, 6, 0.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#546e7a';
      ctx.beginPath();
      ctx.moveTo(-14, 0);
      ctx.lineTo(-22, -8);
      ctx.lineTo(-22, 8);
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.arc(8, -2, 2, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
    }
  },

  triple: {
    id: 'triple',
    name: 'Triple Yarn',
    icon: '🎯',
    color: '#ce93d8',
    trailColor: 'rgba(206,147,216,0.4)',
    damage: 22,
    radius: 36,
    bounces: 0,
    speed: 1.0,
    gravity: 280,
    type: 'scatter',
    count: 3,
    spread: 0.18,
    description: '3 yarn balls in a spread!',
    drawProjectile(ctx, x, y, vx, vy) {
      ctx.save();
      ctx.translate(x, y);
      ctx.fillStyle = '#ce93d8';
      ctx.beginPath(); ctx.arc(0, 0, 6, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#ab47bc';
      ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(0, 0, 4, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
    }
  }
};

const WEAPON_ORDER = ['yarn', 'hairball', 'catnip', 'missile', 'zoomies', 'laser', 'fish', 'triple'];
