'use strict';

// ===========================
// DRAWING HELPERS
// ===========================

function drawPlayer(ctx, x, y, dir, anim, dodging, swordT, swordAngle, upgrades) {
  const t = Math.floor(anim * 4) % 2; // walk frame
  const bob = dodging ? 0 : Math.sin(anim * 12) * 0.8;

  // Shadow
  ctx.fillStyle = 'rgba(0,0,0,0.3)';
  ctx.beginPath();
  ctx.ellipse(x, y+5, 5, 2, 0, 0, Math.PI*2);
  ctx.fill();

  // Cloak/body
  const bodyY = y - 8 + bob;
  ctx.fillStyle = upgrades.has('shadow_cloak') ? '#303060' : C.COL.PLAYER_D;
  ctx.fillRect(x-4, bodyY+2, 8, 9);

  // Head
  ctx.fillStyle = '#f8d090';
  ctx.fillRect(x-3, bodyY-3, 6, 6);

  // Hair
  ctx.fillStyle = '#3a2010';
  ctx.fillRect(x-3, bodyY-3, 6, 2);

  // Eyes (direction-based)
  ctx.fillStyle = C.COL.PLAYER_EYE;
  if (dir === 'down')       { ctx.fillRect(x-2, bodyY+1, 1, 1); ctx.fillRect(x+1, bodyY+1, 1, 1); }
  else if (dir === 'up')    { /* no eyes visible */ }
  else if (dir === 'left')  { ctx.fillRect(x-2, bodyY+1, 1, 1); }
  else if (dir === 'right') { ctx.fillRect(x+1, bodyY+1, 1, 1); }

  // Arm/weapon highlight
  ctx.fillStyle = C.COL.PLAYER;
  ctx.fillRect(x-5, bodyY+3, 2, 5);
  ctx.fillRect(x+3, bodyY+3, 2, 5);

  // Legs
  ctx.fillStyle = C.COL.PLAYER_D;
  if (t === 0) {
    ctx.fillRect(x-3, bodyY+10, 2, 4);
    ctx.fillRect(x+1, bodyY+10, 2, 4);
  } else {
    ctx.fillRect(x-3, bodyY+11, 2, 3);
    ctx.fillRect(x+1, bodyY+9,  2, 5);
  }

  // Sword swing
  if (swordT > 0) {
    const HALF_ARC = Math.PI * 0.65;
    const progress  = 1 - swordT;                              // 0 = start, 1 = finish
    const curAngle  = swordAngle - HALF_ARC + progress * HALF_ARC * 2;
    const ox = x, oy = y - 2;                                  // pivot near hands

    // Sweep-zone wedge (fades as swing completes)
    ctx.save();
    ctx.globalAlpha = swordT * 0.22;
    ctx.fillStyle = C.COL.SWORD_GLOW;
    ctx.beginPath();
    ctx.moveTo(ox, oy);
    ctx.arc(ox, oy, 20, swordAngle - HALF_ARC, swordAngle + HALF_ARC);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    const cos = Math.cos(curAngle), sin = Math.sin(curAngle);
    const HILT = 4, BLADE = 15, GUARD = 4;

    // Grip
    ctx.strokeStyle = '#7a5530';
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(ox, oy);
    ctx.lineTo(ox + cos * HILT, oy + sin * HILT);
    ctx.stroke();

    // Crossguard
    const gx = ox + cos * HILT, gy = oy + sin * HILT;
    const perpA = curAngle + Math.PI / 2;
    ctx.strokeStyle = '#c09040';
    ctx.lineWidth = 1.5;
    ctx.lineCap = 'square';
    ctx.beginPath();
    ctx.moveTo(gx + Math.cos(perpA) * GUARD, gy + Math.sin(perpA) * GUARD);
    ctx.lineTo(gx - Math.cos(perpA) * GUARD, gy - Math.sin(perpA) * GUARD);
    ctx.stroke();

    // Blade glow
    const tipX = ox + cos * (HILT + BLADE), tipY = oy + sin * (HILT + BLADE);
    ctx.save();
    ctx.globalAlpha = 0.4;
    ctx.strokeStyle = C.COL.SWORD_GLOW;
    ctx.lineWidth = 4;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(gx, gy); ctx.lineTo(tipX, tipY);
    ctx.stroke();
    ctx.restore();

    // Blade
    ctx.strokeStyle = C.COL.SWORD;
    ctx.lineWidth = 1.5;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(gx, gy); ctx.lineTo(tipX, tipY);
    ctx.stroke();

    // Tip glint
    ctx.fillStyle = '#e8f0ff';
    ctx.fillRect(tipX - 1, tipY - 1, 2, 2);

    ctx.lineCap = 'butt';
  }

  // Dodge trail
  if (dodging) {
    ctx.globalAlpha = 0.3;
    ctx.fillStyle = C.COL.PLAYER;
    ctx.fillRect(x-4, bodyY, 8, 14);
    ctx.globalAlpha = 1;
  }

  // Orbiting shields upgrade
  if (upgrades.has('orbit_shield')) {
    const t2 = Date.now() / 800;
    for (let i = 0; i < 2; i++) {
      const a = t2 + i * Math.PI;
      const sx2 = x + Math.cos(a) * 12;
      const sy2 = y + Math.sin(a) * 8;
      ctx.fillStyle = C.COL.SHIELD_FG;
      ctx.beginPath();
      ctx.arc(sx2, sy2, 3, 0, Math.PI*2);
      ctx.fill();
    }
  }
}

function drawSlime(ctx, x, y, hp, maxHp, anim, size) {
  const small = size === 'small';
  const h = small ? 5 : 8;
  const w = small ? 6 : 10;
  const bounce = Math.abs(Math.sin(anim * 5)) * 2;

  ctx.fillStyle = 'rgba(0,0,0,0.25)';
  ctx.beginPath();
  ctx.ellipse(x, y+h/2+1, w/2, 1.5, 0, 0, Math.PI*2);
  ctx.fill();

  ctx.fillStyle = C.COL.SLIME_D;
  ctx.beginPath();
  ctx.ellipse(x, y - bounce + 1, w/2, h/2+1, 0, 0, Math.PI*2);
  ctx.fill();

  ctx.fillStyle = C.COL.SLIME;
  ctx.beginPath();
  ctx.ellipse(x, y - bounce, w/2, h/2, 0, 0, Math.PI*2);
  ctx.fill();

  // Eyes
  ctx.fillStyle = C.COL.SLIME_EYE;
  ctx.fillRect(x-2, y-bounce-1, 1, 2);
  ctx.fillRect(x+1, y-bounce-1, 1, 2);
}

function drawBat(ctx, x, y, anim) {
  const flap = Math.sin(anim * 15) * 3;

  ctx.fillStyle = 'rgba(0,0,0,0.2)';
  ctx.beginPath();
  ctx.ellipse(x, y+3, 4, 1.5, 0, 0, Math.PI*2);
  ctx.fill();

  // Wings
  ctx.fillStyle = C.COL.BAT_D;
  ctx.beginPath();
  ctx.moveTo(x, y); ctx.lineTo(x-10, y+flap); ctx.lineTo(x-4, y+3); ctx.closePath(); ctx.fill();
  ctx.beginPath();
  ctx.moveTo(x, y); ctx.lineTo(x+10, y+flap); ctx.lineTo(x+4, y+3); ctx.closePath(); ctx.fill();

  ctx.fillStyle = C.COL.BAT;
  ctx.beginPath();
  ctx.ellipse(x, y, 4, 3, 0, 0, Math.PI*2);
  ctx.fill();

  // Ears
  ctx.fillStyle = C.COL.BAT;
  ctx.fillRect(x-3, y-5, 2, 3);
  ctx.fillRect(x+1, y-5, 2, 3);
  // Eyes
  ctx.fillStyle = '#ff4060';
  ctx.fillRect(x-2, y-1, 1, 1);
  ctx.fillRect(x+1, y-1, 1, 1);
}

function drawSkeleton(ctx, x, y, anim) {
  const walk = Math.sin(anim * 8) * 1.5;

  ctx.fillStyle = 'rgba(0,0,0,0.2)';
  ctx.beginPath();
  ctx.ellipse(x, y+8, 5, 1.5, 0, 0, Math.PI*2);
  ctx.fill();

  // Legs
  ctx.fillStyle = C.COL.SKELETON_D;
  ctx.fillRect(x-3, y+3, 2, 5+walk);
  ctx.fillRect(x+1, y+3, 2, 5-walk);

  // Body/ribcage
  ctx.fillStyle = C.COL.SKELETON;
  ctx.fillRect(x-3, y-3, 6, 7);
  ctx.fillStyle = C.COL.SKELETON_D;
  ctx.fillRect(x-2, y-1, 4, 1);
  ctx.fillRect(x-2, y+1, 4, 1);
  ctx.fillRect(x-2, y+3, 4, 1);

  // Arms
  ctx.fillStyle = C.COL.SKELETON;
  ctx.fillRect(x-5, y-2, 2, 6);
  ctx.fillRect(x+3, y-2, 2, 6);

  // Skull
  ctx.fillStyle = C.COL.SKELETON;
  ctx.fillRect(x-3, y-9, 6, 7);
  ctx.fillStyle = '#1a1a2a';
  ctx.fillRect(x-2, y-7, 2, 2); // eye L
  ctx.fillRect(x+0, y-7, 2, 2); // eye R
  ctx.fillRect(x-1, y-4, 3, 1); // teeth
}

function drawGoblin(ctx, x, y, anim) {
  const walk = Math.sin(anim * 10) * 1.5;

  ctx.fillStyle = 'rgba(0,0,0,0.2)';
  ctx.beginPath();
  ctx.ellipse(x, y+7, 4, 1.5, 0, 0, Math.PI*2);
  ctx.fill();

  ctx.fillStyle = C.COL.GOBLIN_D;
  ctx.fillRect(x-2, y+4+walk, 2, 3);
  ctx.fillRect(x, y+4-walk, 2, 3);

  ctx.fillStyle = C.COL.GOBLIN;
  ctx.fillRect(x-4, y-2, 8, 7);
  ctx.fillRect(x-3, y-7, 6, 6);

  // Big ears
  ctx.fillStyle = C.COL.GOBLIN_D;
  ctx.fillRect(x-6, y-5, 3, 3);
  ctx.fillRect(x+3, y-5, 3, 3);

  // Eyes
  ctx.fillStyle = '#ffff20';
  ctx.fillRect(x-2, y-5, 2, 2);
  ctx.fillRect(x+0, y-5, 2, 2);

  // Weapon
  ctx.fillStyle = '#808088';
  ctx.fillRect(x+4, y-6, 1, 10);
  ctx.fillRect(x+2, y-8, 5, 2);
}

function drawDemon(ctx, x, y, anim) {
  const pulse = Math.sin(anim * 6) * 1;

  ctx.fillStyle = 'rgba(0,0,0,0.25)';
  ctx.beginPath();
  ctx.ellipse(x, y+9, 6, 2, 0, 0, Math.PI*2);
  ctx.fill();

  // Body
  ctx.fillStyle = C.COL.DEMON_D;
  ctx.fillRect(x-5, y-2, 10, 11);
  ctx.fillStyle = C.COL.DEMON;
  ctx.fillRect(x-4, y-3, 8, 10);

  // Head
  ctx.fillStyle = C.COL.DEMON;
  ctx.fillRect(x-4, y-9, 8, 7);
  // Horns
  ctx.fillStyle = '#801020';
  ctx.fillRect(x-5, y-13+pulse, 2, 5);
  ctx.fillRect(x+3, y-13+pulse, 2, 5);

  // Eyes
  ctx.fillStyle = '#ffff00';
  ctx.fillRect(x-3, y-7, 2, 2);
  ctx.fillRect(x+1, y-7, 2, 2);
  // Pupils
  ctx.fillStyle = '#000';
  ctx.fillRect(x-2, y-6, 1, 1);
  ctx.fillRect(x+2, y-6, 1, 1);

  // Wings (simplified)
  ctx.fillStyle = '#601020';
  ctx.beginPath();
  ctx.moveTo(x-4, y); ctx.lineTo(x-14, y-6+pulse); ctx.lineTo(x-5, y+6); ctx.closePath(); ctx.fill();
  ctx.beginPath();
  ctx.moveTo(x+4, y); ctx.lineTo(x+14, y-6+pulse); ctx.lineTo(x+5, y+6); ctx.closePath(); ctx.fill();
}

function drawBoss(ctx, x, y, anim, hp, maxHp) {
  const pulse = Math.sin(anim * 3) * 2;
  const rage = hp / maxHp < 0.5;
  const base = rage ? C.COL.DEMON : C.COL.BOSS;
  const dark = rage ? C.COL.DEMON_D : C.COL.BOSS_D;

  // Shadow
  ctx.fillStyle = 'rgba(0,0,0,0.35)';
  ctx.beginPath();
  ctx.ellipse(x, y+16, 16, 4, 0, 0, Math.PI*2);
  ctx.fill();

  // Robe bottom
  ctx.fillStyle = dark;
  ctx.fillRect(x-12, y+4, 24, 14);
  ctx.fillStyle = base;
  ctx.fillRect(x-10, y+3, 20, 13);

  // Body
  ctx.fillStyle = dark;
  ctx.fillRect(x-10, y-8, 20, 13);
  ctx.fillStyle = base;
  ctx.fillRect(x-8, y-9, 16, 13);

  // Head
  ctx.fillStyle = '#1a0a22';
  ctx.fillRect(x-8, y-22+pulse, 16, 15);
  ctx.fillStyle = dark;
  ctx.fillRect(x-6, y-23+pulse, 12, 14);

  // Crown
  ctx.fillStyle = C.COL.UI_GOLD;
  ctx.fillRect(x-7, y-24+pulse, 14, 3);
  ctx.fillRect(x-8, y-27+pulse, 3, 4);
  ctx.fillRect(x-2, y-26+pulse, 4, 3);
  ctx.fillRect(x+5, y-27+pulse, 3, 4);

  // Eyes
  const eyeColor = rage ? '#ff2020' : '#cc80ff';
  ctx.fillStyle = eyeColor;
  ctx.fillRect(x-5, y-18+pulse, 3, 3);
  ctx.fillRect(x+2, y-18+pulse, 3, 3);
  // Glow
  ctx.globalAlpha = 0.4 + Math.sin(anim * 8) * 0.2;
  ctx.fillStyle = eyeColor;
  ctx.fillRect(x-6, y-19+pulse, 5, 5);
  ctx.fillRect(x+1, y-19+pulse, 5, 5);
  ctx.globalAlpha = 1;

  // Arms / scepter
  ctx.fillStyle = dark;
  ctx.fillRect(x-14, y-4, 4, 12);
  ctx.fillRect(x+10, y-4, 4, 12);
  // Scepter
  ctx.fillStyle = '#604080';
  ctx.fillRect(x+13, y-12, 2, 18);
  ctx.fillStyle = C.COL.UI_PURPLE;
  ctx.beginPath();
  ctx.arc(x+14, y-14+pulse, 4, 0, Math.PI*2);
  ctx.fill();
}

function drawChest(ctx, x, y, opened) {
  ctx.fillStyle = C.COL.CHEST_BAND;
  ctx.fillRect(x, y, 12, 9);
  ctx.fillStyle = C.COL.CHEST;
  ctx.fillRect(x+1, y+1, 10, 7);
  ctx.fillStyle = C.COL.CHEST_LID;
  ctx.fillRect(x, y, 12, opened ? 3 : 4);
  ctx.fillStyle = C.COL.UI_GOLD;
  ctx.fillRect(x+5, y+4, 2, 2);
  if (opened) {
    ctx.globalAlpha = 0.6;
    ctx.fillStyle = '#ffeea0';
    ctx.fillRect(x, y-2, 12, 4);
    ctx.globalAlpha = 1;
  }
}

function drawCoin(ctx, x, y, anim) {
  const s = Math.abs(Math.cos(anim * 4)) * 2 + 3;
  ctx.fillStyle = C.COL.COIN_D;
  ctx.beginPath();
  ctx.ellipse(x, y+1, s, 3, 0, 0, Math.PI*2);
  ctx.fill();
  ctx.fillStyle = C.COL.COIN;
  ctx.beginPath();
  ctx.ellipse(x, y, s, 3, 0, 0, Math.PI*2);
  ctx.fill();
  ctx.fillStyle = '#ffffc0';
  ctx.beginPath();
  ctx.ellipse(x-1, y-1, s*0.4, 1, 0, 0, Math.PI*2);
  ctx.fill();
}

function drawArrow(ctx, x, y, angle) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.fillStyle = C.COL.ARROW;
  ctx.fillRect(-6, -1, 12, 2);
  ctx.fillStyle = C.COL.ARROW_TIP;
  ctx.beginPath();
  ctx.moveTo(6, 0); ctx.lineTo(3, -3); ctx.lineTo(3, 3); ctx.closePath(); ctx.fill();
  ctx.restore();
}

function drawMagicBolt(ctx, x, y, angle, color) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  // Glow
  ctx.globalAlpha = 0.4;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(0, 0, 8, 4, 0, 0, Math.PI*2);
  ctx.fill();
  ctx.globalAlpha = 1;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(0, 0, 5, 2, 0, 0, Math.PI*2);
  ctx.fill();
  ctx.fillStyle = '#ffffff';
  ctx.beginPath();
  ctx.ellipse(-1, 0, 2, 1, 0, 0, Math.PI*2);
  ctx.fill();
  ctx.restore();
}

function drawBoneBolt(ctx, x, y, angle) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.fillStyle = C.COL.SKELETON;
  ctx.fillRect(-5, -1.5, 10, 3);
  ctx.fillRect(-6, -2, 3, 4);
  ctx.fillRect(3, -2, 3, 4);
  ctx.restore();
}

// ===========================
// PROJECTILE
// ===========================
class Projectile {
  constructor(x, y, vx, vy, opts) {
    this.x = x; this.y = y;
    this.vx = vx; this.vy = vy;
    this.owner = opts.owner || 'player';  // 'player' or 'enemy'
    this.dmg = opts.dmg || 1;
    this.range = opts.range || C.P_PROJ_RANGE;
    this.traveled = 0;
    this.alive = true;
    this.piercing = opts.piercing || false;
    this.homing = opts.homing || false;
    this.type = opts.type || 'arrow';
    this.color = opts.color || C.COL.ARROW;
    this.size = opts.size || 3;
    this.hit = new Set();
  }

  update(dt, room, enemies, player) {
    if (!this.alive) return;

    if (this.homing && this.owner === 'player' && enemies.length > 0) {
      let nearest = null, nearD = Infinity;
      for (const e of enemies) {
        const d = dist2(this.x, this.y, e.x, e.y);
        if (d < nearD) { nearD = d; nearest = e; }
      }
      if (nearest) {
        const n = norm(nearest.x - this.x, nearest.y - this.y);
        const spd = Math.sqrt(this.vx**2 + this.vy**2);
        this.vx = lerp(this.vx, n.x * spd, 3 * dt);
        this.vy = lerp(this.vy, n.y * spd, 3 * dt);
      }
    }

    const spd = Math.sqrt(this.vx**2 + this.vy**2);
    this.x += this.vx * dt;
    this.y += this.vy * dt;
    this.traveled += spd * dt;

    if (this.traveled > this.range) { this.alive = false; return; }

    // Tile collision
    const tx = Math.floor(this.x / C.TS), ty = Math.floor(this.y / C.TS);
    if (isSolid(room.getTile(tx, ty)) && !isOpenDoor(room.getTile(tx, ty))) {
      Particles.hit(this.x, this.y, this.color);
      this.alive = false;
      return;
    }

    // Enemy hits (player projectiles)
    if (this.owner === 'player') {
      for (const e of enemies) {
        if (e.dead || this.hit.has(e)) continue;
        if (circleCircle(this.x, this.y, this.size, e.x, e.y, e.size)) {
          e.takeDamage(this.dmg, this.x, this.y);
          this.hit.add(e);
          if (!this.piercing) { this.alive = false; return; }
        }
      }
    }

    // Player hit (enemy projectiles)
    if (this.owner === 'enemy' && player && !player.invincible && !player.dodging) {
      if (circleCircle(this.x, this.y, this.size, player.x, player.y, C.P_SIZE)) {
        player.takeDamage(this.dmg);
        Particles.hit(this.x, this.y, C.COL.PARTICLE_HIT);
        this.alive = false;
      }
    }
  }

  draw(ctx) {
    if (!this.alive) return;
    const angle = Math.atan2(this.vy, this.vx);
    if (this.type === 'arrow')       drawArrow(ctx, this.x, this.y, angle);
    else if (this.type === 'magic')  drawMagicBolt(ctx, this.x, this.y, angle, this.color);
    else if (this.type === 'bone')   drawBoneBolt(ctx, this.x, this.y, angle);
  }
}

// ===========================
// BASE ENEMY
// ===========================
class Enemy {
  constructor(x, y, opts) {
    this.x = x; this.y = y;
    this.hp = opts.hp || 4;
    this.maxHp = this.hp;
    this.atk = opts.atk || 1;
    this.size = opts.size || 6;
    this.speed = opts.speed || 45;
    this.kind = opts.kind || 'slime';
    this.dead = false;
    this.anim = rFloat(0, 10);
    this.hitFlash = 0;
    this.vx = 0; this.vy = 0;
    this.coins = opts.coins || rInt(0, 2);
    this.xp = opts.xp || 5;
    this.stunTimer = 0;
    this.poisonTimer = 0;
    this.poisonTick = 0;
    this.fireTimer = 0;
    this.fireTick = 0;
    this.shootTimer = rFloat(1, 3);
    this.shootCooldown = opts.shootCd || 2.5;
    this.wanderAngle = rFloat(0, Math.PI * 2);
    this.wanderTimer = 0;
    this.aggroRange = opts.aggroRange || 120;
    this.phase = 1;
  }

  takeDamage(dmg, sx, sy) {
    if (this.dead) return;
    const actual = Math.max(1, dmg);
    this.hp -= actual;
    this.hitFlash = 0.15;
    Particles.hit(this.x, this.y - this.size, C.COL.PARTICLE_HIT);
    Particles.damage(this.x, this.y - this.size, actual);
    Audio.play('enemy_hit');
    if (this.hp <= 0) this._die();
  }

  applyPoison(duration) {
    this.poisonTimer = Math.max(this.poisonTimer, duration);
    this.poisonTick = 0;
  }

  applyFire(duration) {
    this.fireTimer = Math.max(this.fireTimer, duration);
    this.fireTick = 0;
  }

  _die() {
    this.dead = true;
    Particles.death(this.x, this.y, this._deathColor());
    Audio.play('kill');
  }

  _deathColor() { return '#ffffff'; }

  _moveToward(tx, ty, dt) {
    const n = norm(tx - this.x, ty - this.y);
    this.vx = lerp(this.vx, n.x * this.speed, 8 * dt);
    this.vy = lerp(this.vy, n.y * this.speed, 8 * dt);
  }

  _wander(dt) {
    this.wanderTimer -= dt;
    if (this.wanderTimer <= 0) {
      this.wanderAngle += rFloat(-1.5, 1.5);
      this.wanderTimer = rFloat(0.5, 1.5);
    }
    this.vx = lerp(this.vx, Math.cos(this.wanderAngle) * this.speed * 0.5, 3 * dt);
    this.vy = lerp(this.vy, Math.sin(this.wanderAngle) * this.speed * 0.5, 3 * dt);
  }

  _resolveWall(room) {
    const r = this.size;
    if (!room.canWalk(this.x - r, this.y)) { this.x = Math.ceil((this.x - r) / C.TS) * C.TS + r; this.vx *= -0.5; }
    if (!room.canWalk(this.x + r, this.y)) { this.x = Math.floor((this.x + r) / C.TS) * C.TS - r; this.vx *= -0.5; }
    if (!room.canWalk(this.x, this.y - r)) { this.y = Math.ceil((this.y - r) / C.TS) * C.TS + r; this.vy *= -0.5; }
    if (!room.canWalk(this.x, this.y + r)) { this.y = Math.floor((this.y + r) / C.TS) * C.TS - r; this.vy *= -0.5; }
  }

  _baseUpdate(dt, player, room) {
    this.anim += dt;
    if (this.hitFlash > 0) this.hitFlash -= dt;

    if (this.stunTimer > 0) { this.stunTimer -= dt; this.vx *= 0.8; this.vy *= 0.8; }

    if (this.poisonTimer > 0) {
      this.poisonTimer -= dt;
      this.poisonTick -= dt;
      if (this.poisonTick <= 0) {
        this.poisonTick = 0.5;
        this.takeDamage(1);
        Particles.poison(this.x, this.y - this.size);
      }
    }

    if (this.fireTimer > 0) {
      this.fireTimer -= dt;
      this.fireTick -= dt;
      if (this.fireTick <= 0) {
        this.fireTick = 0.4;
        this.takeDamage(1);
        Particles.burst(this.x, this.y, 3, {
          color: '#ff8020', minSpd: 20, maxSpd: 60,
          minLife: 0.2, maxLife: 0.4, minSize: 1, maxSize: 3, gravity: -30,
        });
      }
    }
  }

  _drawHpBar(ctx) {
    if (this.hp >= this.maxHp) return;
    const bw = this.size * 2.5;
    drawBar(ctx, this.x - bw/2, this.y - this.size - 5, bw, 2,
      this.hp, this.maxHp, C.COL.HP_FG, C.COL.HP_BG);
  }

  update(dt, player, room, projectiles) { /* override */ }

  draw(ctx) {
    if (this.hitFlash > 0) { ctx.globalAlpha = 0.6; }

    // Poison/fire tint
    if (this.poisonTimer > 0) ctx.globalAlpha = 0.8;
    if (this.fireTimer > 0)   ctx.globalAlpha = 0.7;

    this._drawSprite(ctx);

    ctx.globalAlpha = 1;
    this._drawHpBar(ctx);

    // Status effect overlay
    if (this.poisonTimer > 0) {
      ctx.globalAlpha = 0.3;
      ctx.fillStyle = '#80ff40';
      ctx.beginPath(); ctx.arc(this.x, this.y, this.size + 2, 0, Math.PI*2); ctx.fill();
      ctx.globalAlpha = 1;
    }
    if (this.fireTimer > 0) {
      ctx.globalAlpha = 0.3;
      ctx.fillStyle = '#ff8020';
      ctx.beginPath(); ctx.arc(this.x, this.y, this.size + 2, 0, Math.PI*2); ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  _drawSprite(ctx) {}
}

// ===========================
// SLIME
// ===========================
class Slime extends Enemy {
  constructor(x, y, floor, small) {
    const hp = (small ? 1 : 3) + Math.floor(floor * 0.5);
    super(x, y, {
      hp, atk: 1, size: small ? 4 : 7,
      speed: small ? 55 : 38, kind: 'slime',
      coins: small ? 0 : rInt(0, 2), xp: small ? 2 : 5,
    });
    this.small = small;
  }

  update(dt, player, room, projectiles) {
    this._baseUpdate(dt, player, room);
    if (this.dead || this.stunTimer > 0) return;
    const d = dist(this.x, this.y, player.x, player.y);
    if (d < this.aggroRange) this._moveToward(player.x, player.y, dt);
    else this._wander(dt);
    this.x += this.vx * dt; this.y += this.vy * dt;
    this._resolveWall(room);
    if (d < this.size + C.P_SIZE) {
      player.takeDamage(this.atk);
    }
  }

  _die() {
    super._die();
    if (!this.small) {
      // Return split children to game via a flag
      this.splitChildren = [
        {x: this.x - 8, y: this.y},
        {x: this.x + 8, y: this.y},
      ];
    }
  }

  _deathColor() { return C.COL.SLIME; }
  _drawSprite(ctx) { drawSlime(ctx, this.x, this.y, this.hp, this.maxHp, this.anim, this.small ? 'small' : 'big'); }
}

// ===========================
// BAT
// ===========================
class Bat extends Enemy {
  constructor(x, y, floor) {
    super(x, y, {
      hp: 2 + Math.floor(floor * 0.3), atk: 1, size: 5,
      speed: 75, kind: 'bat', coins: rInt(0, 1), xp: 4,
    });
    this.swoopTimer = rFloat(2, 4);
    this.swoopDir = {x: 0, y: 0};
    this.swooping = false;
  }

  update(dt, player, room, projectiles) {
    this._baseUpdate(dt, player, room);
    if (this.dead || this.stunTimer > 0) return;

    this.swoopTimer -= dt;
    if (this.swoopTimer <= 0 && !this.swooping) {
      const n = norm(player.x - this.x, player.y - this.y);
      this.swoopDir = n;
      this.swooping = true;
      this.swoopTimer = rFloat(2.5, 4);
    }

    if (this.swooping) {
      this.vx = lerp(this.vx, this.swoopDir.x * 140, 6 * dt);
      this.vy = lerp(this.vy, this.swoopDir.y * 140, 6 * dt);
      if (Math.sqrt(this.vx**2+this.vy**2) < 20) this.swooping = false;
    } else {
      this._wander(dt);
    }

    this.x += this.vx * dt; this.y += this.vy * dt;
    this._resolveWall(room);
    const d = dist(this.x, this.y, player.x, player.y);
    if (d < this.size + C.P_SIZE) player.takeDamage(this.atk);
  }

  _deathColor() { return C.COL.BAT; }
  _drawSprite(ctx) { drawBat(ctx, this.x, this.y, this.anim); }
}

// ===========================
// SKELETON
// ===========================
class Skeleton extends Enemy {
  constructor(x, y, floor) {
    super(x, y, {
      hp: 4 + floor, atk: 1, size: 6,
      speed: 30, kind: 'skeleton', coins: rInt(1, 2), xp: 8,
      shootCd: 2.2,
    });
    this.preferRange = 70;
  }

  update(dt, player, room, projectiles) {
    this._baseUpdate(dt, player, room);
    if (this.dead || this.stunTimer > 0) return;

    const d = dist(this.x, this.y, player.x, player.y);
    if (d < this.aggroRange) {
      if (d < this.preferRange - 10) {
        // Back away
        const n = norm(this.x - player.x, this.y - player.y);
        this.vx = lerp(this.vx, n.x * this.speed, 5 * dt);
        this.vy = lerp(this.vy, n.y * this.speed, 5 * dt);
      } else if (d > this.preferRange + 10) {
        this._moveToward(player.x, player.y, dt);
      } else {
        this.vx *= 0.9; this.vy *= 0.9;
      }

      // Shoot bone
      this.shootTimer -= dt;
      if (this.shootTimer <= 0) {
        this.shootTimer = this.shootCooldown + rFloat(-0.3, 0.3);
        const n = norm(player.x - this.x, player.y - this.y);
        const spd = 90;
        projectiles.push(new Projectile(this.x, this.y, n.x * spd, n.y * spd, {
          owner: 'enemy', dmg: this.atk, type: 'bone',
          range: 160, color: C.COL.SKELETON, size: 4,
        }));
      }
    } else {
      this._wander(dt);
    }

    this.x += this.vx * dt; this.y += this.vy * dt;
    this._resolveWall(room);
  }

  _deathColor() { return C.COL.SKELETON; }
  _drawSprite(ctx) { drawSkeleton(ctx, this.x, this.y, this.anim); }
}

// ===========================
// GOBLIN
// ===========================
class Goblin extends Enemy {
  constructor(x, y, floor) {
    super(x, y, {
      hp: 5 + floor, atk: 2, size: 6,
      speed: 68, kind: 'goblin', coins: rInt(1, 3), xp: 10,
    });
    this.chargeTimer = rFloat(2, 4);
    this.charging = false;
    this.chargeDir = {x:0,y:0};
  }

  update(dt, player, room, projectiles) {
    this._baseUpdate(dt, player, room);
    if (this.dead || this.stunTimer > 0) return;

    const d = dist(this.x, this.y, player.x, player.y);
    this.chargeTimer -= dt;

    if (this.charging) {
      this.vx = lerp(this.vx, this.chargeDir.x * 180, 4 * dt);
      this.vy = lerp(this.vy, this.chargeDir.y * 180, 4 * dt);
      if (Math.sqrt(this.vx**2+this.vy**2) < 30) this.charging = false;
    } else if (d < this.aggroRange) {
      if (this.chargeTimer <= 0 && d < 80) {
        const n = norm(player.x - this.x, player.y - this.y);
        this.chargeDir = n;
        this.charging = true;
        this.chargeTimer = rFloat(2, 3.5);
      } else {
        this._moveToward(player.x, player.y, dt);
      }
    } else {
      this._wander(dt);
    }

    this.x += this.vx * dt; this.y += this.vy * dt;
    this._resolveWall(room);
    if (d < this.size + C.P_SIZE) player.takeDamage(this.atk);
  }

  _deathColor() { return C.COL.GOBLIN; }
  _drawSprite(ctx) { drawGoblin(ctx, this.x, this.y, this.anim); }
}

// ===========================
// DEMON
// ===========================
class Demon extends Enemy {
  constructor(x, y, floor) {
    super(x, y, {
      hp: 8 + floor * 2, atk: 2, size: 8,
      speed: 55, kind: 'demon', coins: rInt(2, 4), xp: 18,
      shootCd: 1.8,
    });
    this.teleportTimer = rFloat(5, 8);
  }

  update(dt, player, room, projectiles) {
    this._baseUpdate(dt, player, room);
    if (this.dead || this.stunTimer > 0) return;

    const d = dist(this.x, this.y, player.x, player.y);
    this.teleportTimer -= dt;
    if (this.teleportTimer <= 0) {
      // Teleport near player
      const pts = room.spawnPoints().slice(0, 10);
      const near = pts.find(p => dist(p.x, p.y, player.x, player.y) > 40 && dist(p.x,p.y,player.x,player.y) < 100);
      if (near) {
        Particles.magic(this.x, this.y);
        this.x = near.x; this.y = near.y;
        Particles.magic(this.x, this.y);
      }
      this.teleportTimer = rFloat(5, 8);
    }

    if (d < this.aggroRange) {
      this._moveToward(player.x, player.y, dt);
      this.shootTimer -= dt;
      if (this.shootTimer <= 0) {
        this.shootTimer = this.shootCooldown;
        for (let i = 0; i < 3; i++) {
          const a = ang(this.x,this.y,player.x,player.y) + (i-1) * 0.4;
          const spd = 95;
          projectiles.push(new Projectile(this.x, this.y, Math.cos(a)*spd, Math.sin(a)*spd, {
            owner: 'enemy', dmg: this.atk, type: 'magic',
            range: 140, color: C.COL.DEMON, size: 4,
          }));
        }
      }
    } else {
      this._wander(dt);
    }

    this.x += this.vx * dt; this.y += this.vy * dt;
    this._resolveWall(room);
    if (d < this.size + C.P_SIZE) player.takeDamage(this.atk);
  }

  _deathColor() { return C.COL.DEMON; }
  _drawSprite(ctx) { drawDemon(ctx, this.x, this.y, this.anim); }
}

// ===========================
// BOSS: THE LICH
// ===========================
class Boss extends Enemy {
  constructor(x, y, floor) {
    const hp = 60 + floor * 20;
    super(x, y, {
      hp, atk: 3, size: 16, speed: 40, kind: 'boss',
      coins: rInt(8, 15), xp: 100, aggroRange: 200, shootCd: 1.2,
    });
    this.summonTimer = rFloat(6, 10);
    this.phase2Triggered = false;
    this.orbAngle = 0;
  }

  update(dt, player, room, projectiles, onSummon) {
    this._baseUpdate(dt, player, room);
    if (this.dead) return;

    // Phase 2 at 50% HP
    if (!this.phase2Triggered && this.hp < this.maxHp * 0.5) {
      this.phase2Triggered = true;
      this.speed *= 1.5;
      this.shootCooldown *= 0.7;
      Audio.play('boss_enter');
      Particles.explosion(this.x, this.y);
    }

    const d = dist(this.x, this.y, player.x, player.y);

    // Movement: circle the player
    const targetAngle = ang(player.x, player.y, this.x, this.y) + 0.015;
    const orbitDist = 80;
    const tx = player.x + Math.cos(targetAngle) * orbitDist;
    const ty = player.y + Math.sin(targetAngle) * orbitDist;
    this._moveToward(tx, ty, dt);
    this.x += this.vx * dt; this.y += this.vy * dt;
    this._resolveWall(room);

    // Shoot spiral of bolts
    this.shootTimer -= dt;
    if (this.shootTimer <= 0) {
      this.shootTimer = this.shootCooldown;
      this.orbAngle += 0.8;
      const count = this.phase2Triggered ? 6 : 4;
      for (let i = 0; i < count; i++) {
        const a = this.orbAngle + (i / count) * Math.PI * 2;
        const spd = 70;
        projectiles.push(new Projectile(this.x, this.y, Math.cos(a)*spd, Math.sin(a)*spd, {
          owner: 'enemy', dmg: this.atk, type: 'magic',
          range: 200, color: C.COL.BOSS, size: 5,
        }));
      }
    }

    // Summon minions
    this.summonTimer -= dt;
    if (this.summonTimer <= 0) {
      this.summonTimer = rFloat(8, 14);
      if (onSummon) onSummon();
    }

    if (d < this.size + C.P_SIZE) player.takeDamage(this.atk);
  }

  takeDamage(dmg, sx, sy) {
    if (this.dead) return;
    const actual = Math.max(1, dmg);
    this.hp -= actual;
    this.hitFlash = 0.15;
    Particles.hit(this.x, this.y, C.COL.BOSS);
    Particles.damage(this.x, this.y - this.size, actual);
    Audio.play('boss_hit');
    if (this.hp <= 0) this._die();
  }

  _die() {
    this.dead = true;
    Particles.explosion(this.x, this.y);
    Particles.explosion(this.x - 10, this.y + 5);
    Particles.explosion(this.x + 10, this.y - 5);
    Audio.play('victory');
  }

  _deathColor() { return C.COL.BOSS; }
  _drawSprite(ctx) { drawBoss(ctx, this.x, this.y, this.anim, this.hp, this.maxHp); }
}

// ===========================
// PLAYER
// ===========================
class Player {
  constructor() {
    this.reset();
  }

  reset() {
    this.x = C.VW / 2;
    this.y = C.VH / 2;
    this.vx = 0; this.vy = 0;
    this.dir = 'down';
    this.anim = 0;
    this.moving = false;

    // Core stats
    this.maxHp = C.P_MAX_HP;
    this.hp = this.maxHp;
    this.atk = C.P_ATK;
    this.def = C.P_DEF;
    this.speed = C.P_SPEED;
    this.luck = 0;

    // Combat state
    this.swordTimer = 0;
    this.swordCooldown = 0;
    this.swordAngle = 0;
    this.shootCooldown = 0;
    this.dodgeSpeed = C.P_DODGE_SPEED;
    this.dodgeTimer = 0;
    this.dodgeCooldown = 0;
    this.dodging = false;
    this.dodgeVx = 0; this.dodgeVy = 0;
    this.invincibleTimer = 0;

    // Upgrades
    this.upgrades = new Map();  // id -> level
    this.upgradeSet = new Set(); // for quick has() checks

    // Resources
    this.coins = 0;
    this.xp = 0;
    this.xpNext = 20;
    this.level = 1;
    this.kills = 0;
    this.roomsCleared = 0;

    // Regen
    this.regenTimer = 0;
    this.regenRate = 0;

    // Soul stack (soul_rend upgrade)
    this.soulStacks = 0;
    this.soulTimer = 0;

    // Temp step sound
    this.stepTimer = 0;
  }

  get invincible() { return this.invincibleTimer > 0 || this.dodging; }

  addUpgrade(id) {
    const lvl = (this.upgrades.get(id) || 0) + 1;
    this.upgrades.set(id, lvl);
    this.upgradeSet.add(id);
    Upgrades.applyEffect(this, id, lvl);
  }

  hasUpgrade(id) { return this.upgradeSet.has(id); }
  upgradeLevel(id) { return this.upgrades.get(id) || 0; }

  takeDamage(dmg) {
    if (this.invincible) return;
    const actual = Math.max(1, dmg - this.def);

    // Shield block upgrade: 20% chance
    if (this.hasUpgrade('shield_block') && Math.random() < 0.2) {
      Particles.magic(this.x, this.y);
      return;
    }

    this.hp -= actual;
    this.invincibleTimer = C.P_INVINCIBLE_DURATION;
    Particles.hit(this.x, this.y - 4, C.COL.PARTICLE_HIT);
    Particles.damage(this.x, this.y - 8, actual);
    Audio.play('player_hit');

    // Thorns: dealt nearby (handled externally)
    if (this.hp <= 0) { this.hp = 0; }
  }

  heal(amount) {
    const prev = this.hp;
    this.hp = Math.min(this.maxHp, this.hp + amount);
    if (this.hp > prev) {
      Particles.heal(this.x, this.y);
      Audio.play('heal');
    }
  }

  gainXP(amount) {
    this.xp += amount;
    if (this.xp >= this.xpNext) {
      this.xp -= this.xpNext;
      this.level++;
      this.xpNext = Math.round(this.xpNext * 1.4);
    }
  }

  getSwordDmg() {
    let dmg = this.atk;
    if (this.hasUpgrade('soul_rend')) dmg += Math.min(this.soulStacks, 5);
    if (this.hasUpgrade('berserker_rage') && this.hp <= this.maxHp * 0.3) dmg = Math.ceil(dmg * 1.6);
    if (this.hasUpgrade('last_stand') && this.hp <= 3) dmg = Math.ceil(dmg * 1.5);
    // Crit
    if (this.hasUpgrade('critical_force') && Math.random() < 0.15 + this.upgradeLevel('critical_force') * 0.05) {
      dmg *= 2;
    }
    return Math.ceil(dmg);
  }

  getProjDmg() {
    let dmg = Math.ceil(this.atk * 0.7);
    if (this.hasUpgrade('berserker_rage') && this.hp <= this.maxHp * 0.3) dmg = Math.ceil(dmg * 1.5);
    if (this.hasUpgrade('critical_force') && Math.random() < 0.15) dmg *= 2;
    return Math.max(1, dmg);
  }

  getSwordRange() {
    let r = C.P_SWORD_RANGE;
    if (this.hasUpgrade('giant_blade')) r *= 1.5;
    return r;
  }

  getProjCount() {
    return 1 + (this.upgradeLevel('multishot') || 0);
  }

  update(dt, room, projectiles) {
    this.anim += dt;
    if (this.invincibleTimer > 0) this.invincibleTimer -= dt;
    if (this.swordCooldown > 0) this.swordCooldown -= dt;
    if (this.shootCooldown > 0) this.shootCooldown -= dt;
    if (this.dodgeCooldown > 0) this.dodgeCooldown -= dt;
    if (this.swordTimer > 0) this.swordTimer -= dt;

    // Regen
    if (this.regenRate > 0) {
      this.regenTimer += dt;
      if (this.regenTimer >= 1 / this.regenRate) {
        this.regenTimer = 0;
        this.heal(1);
      }
    }

    // Soul rend decay
    if (this.hasUpgrade('soul_rend') && this.soulStacks > 0) {
      this.soulTimer -= dt;
      if (this.soulTimer <= 0) {
        this.soulStacks = Math.max(0, this.soulStacks - 1);
        this.soulTimer = 8;
      }
    }

    // Dodge
    if (this.dodging) {
      this.dodgeTimer -= dt;
      if (this.dodgeTimer <= 0) this.dodging = false;
      else {
        this.x += this.dodgeVx * dt;
        this.y += this.dodgeVy * dt;
        this._resolveWall(room);
        return;
      }
    }

    // Movement
    let mx = Input.moveX(), my = Input.moveY();
    const moving = mx !== 0 || my !== 0;

    if (moving) {
      const n = norm(mx, my);
      mx = n.x; my = n.y;
      if (Math.abs(mx) > 0.5) this.dir = mx > 0 ? 'right' : 'left';
      else this.dir = my > 0 ? 'down' : 'up';

      this.stepTimer -= dt;
      if (this.stepTimer <= 0) {
        this.stepTimer = 0.3;
        Audio.play('step');
      }
    }

    // Momentum upgrade: speed increases while moving
    let spd = this.speed;
    if (this.hasUpgrade('momentum') && moving) {
      spd *= 1 + Math.min(this.anim * 0.1, 0.4);
    }

    this.vx = lerp(this.vx, mx * spd, 12 * dt);
    this.vy = lerp(this.vy, my * spd, 12 * dt);
    this.x += this.vx * dt;
    this.y += this.vy * dt;
    this.moving = moving;

    this._resolveWall(room);

    // Orbiting shield collision
    if (this.hasUpgrade('orbit_shield')) {
      // Handled externally in game update
    }

    // Dodge input
    if (Input.wantDodge() && this.dodgeCooldown <= 0) {
      const dx = mx || (this.dir === 'right' ? 1 : this.dir === 'left' ? -1 : 0);
      const dy = my || (this.dir === 'down' ? 1 : this.dir === 'up' ? -1 : 0);
      if (dx !== 0 || dy !== 0) {
        const n = norm(dx, dy);
        this.dodgeVx = n.x * this.dodgeSpeed;
        this.dodgeVy = n.y * this.dodgeSpeed;
        this.dodging = true;
        this.dodgeTimer = C.P_DODGE_DURATION;
        this.dodgeCooldown = C.P_DODGE_COOLDOWN * (this.hasUpgrade('dodge_master') ? 0.65 : 1);
      }
    }

    // Sword swing
    const mouseAngle = ang(this.x, this.y, Input.mouse.x, Input.mouse.y);
    if (Input.wantSword() && this.swordCooldown <= 0) {
      this.swordTimer = C.P_SWORD_DURATION;
      this.swordAngle = mouseAngle;
      this.swordCooldown = C.P_SWORD_COOLDOWN * (this.hasUpgrade('swift_strikes') ? 0.75 : 1);
      Audio.play('sword');

      // Return hit result to caller (handled in game.js)
      this._swingPending = true;
    }

    // Shoot
    if (Input.wantShoot() && this.shootCooldown <= 0) {
      this.shootCooldown = C.P_SHOOT_COOLDOWN;
      const spd2 = C.P_PROJ_SPEED;
      const count = this.getProjCount();
      const spread = 0.18;
      for (let i = 0; i < count; i++) {
        const a = mouseAngle + (i - (count-1)/2) * spread;
        const dmg = this.getProjDmg();
        const p = new Projectile(this.x, this.y, Math.cos(a)*spd2, Math.sin(a)*spd2, {
          owner: 'player', dmg,
          range: C.P_PROJ_RANGE * (this.hasUpgrade('longer_range') ? 1.4 : 1),
          piercing: this.hasUpgrade('piercing_shots'),
          homing: this.hasUpgrade('homing_bolts'),
          type: 'magic',
          color: this.hasUpgrade('fire_aspect') ? '#ff8020' : C.COL.UI_PURPLE,
          size: 4,
        });
        projectiles.push(p);
      }
      Audio.play('shoot');
    }
  }

  doSwordHit(enemies, room) {
    if (!this._swingPending) return [];
    this._swingPending = false;

    const range = this.getSwordRange();
    const dmg = this.getSwordDmg();
    const hit = [];

    for (const e of enemies) {
      if (e.dead) continue;
      const d = dist(this.x, this.y, e.x, e.y);
      if (d <= range + e.size) {
        // Angle check
        const a = ang(this.x, this.y, e.x, e.y);
        const diff = Math.abs(((a - this.swordAngle) + Math.PI * 3) % (Math.PI * 2) - Math.PI);
        if (diff < Math.PI * 0.65) {
          e.takeDamage(dmg, this.x, this.y);
          hit.push(e);

          // Poison touch
          if (this.hasUpgrade('poison_touch')) e.applyPoison(4);
          // Fire aspect
          if (this.hasUpgrade('fire_aspect')) e.applyFire(3);
          // Lifesteal
          if (this.hasUpgrade('vampiric')) this.heal(1);
          // Stun on dodge
          if (this.dodging && this.hasUpgrade('shield_bash')) e.stunTimer = 1.5;
        }
      }
    }
    return hit;
  }

  _resolveWall(room) {
    const r = C.P_SIZE;
    if (!room.canWalk(this.x - r, this.y)) { this.x = Math.ceil((this.x-r)/C.TS)*C.TS+r; this.vx=0; }
    if (!room.canWalk(this.x + r, this.y)) { this.x = Math.floor((this.x+r)/C.TS)*C.TS-r; this.vx=0; }
    if (!room.canWalk(this.x, this.y - r)) { this.y = Math.ceil((this.y-r)/C.TS)*C.TS+r; this.vy=0; }
    if (!room.canWalk(this.x, this.y + r)) { this.y = Math.floor((this.y+r)/C.TS)*C.TS-r; this.vy=0; }
  }

  draw(ctx) {
    if (this.invincibleTimer > 0 && Math.floor(this.anim * 15) % 2 === 0) {
      ctx.globalAlpha = 0.4;
    }
    drawPlayer(ctx, this.x, this.y, this.dir, this.anim, this.dodging,
      this.swordTimer / C.P_SWORD_DURATION, this.swordAngle, this.upgradeSet);
    ctx.globalAlpha = 1;
  }
}

// ===========================
// FACTORY
// ===========================
function spawnEnemies(room, floor) {
  const pts = room.spawnPoints();
  if (!pts.length) return [];

  const kinds = floor <= 1 ? ['slime','bat'] :
                floor <= 2 ? ['slime','bat','skeleton'] :
                floor <= 3 ? ['slime','bat','skeleton','goblin'] :
                             ['bat','skeleton','goblin','demon'];

  let count;
  if (room.type === RTYPE.BOSS) {
    return [new Boss(C.VW/2, C.VH/2, floor)];
  }
  count = rInt(2 + floor, Math.min(5 + floor, 8));

  const enemies = [];
  for (let i = 0; i < Math.min(count, pts.length); i++) {
    const pt = pts[i];
    const kind = rPick(kinds);
    switch (kind) {
      case 'slime':    enemies.push(new Slime(pt.x, pt.y, floor, false)); break;
      case 'bat':      enemies.push(new Bat(pt.x, pt.y, floor)); break;
      case 'skeleton': enemies.push(new Skeleton(pt.x, pt.y, floor)); break;
      case 'goblin':   enemies.push(new Goblin(pt.x, pt.y, floor)); break;
      case 'demon':    enemies.push(new Demon(pt.x, pt.y, floor)); break;
    }
  }
  return enemies;
}
