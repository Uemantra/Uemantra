const CANVAS_W = 1200;
const CANVAS_H = 640;
const MOVE_BUDGET = 120;

const KITTEN_COLORS = [
  { body: '#e8842a', stripe: '#c06010', belly: '#f5c48a', name: 'Orange' },
  { body: '#7a8fa0', stripe: '#4a6070', belly: '#c8d8e8', name: 'Grey'   }
];

// ---- Kitten entity ----

class Kitten {
  constructor(x, y, playerId) {
    this.x = x; this.y = y;
    this.playerId = playerId;
    this.health = 100;
    this.facing = playerId === 1 ? 'right' : 'left';
    this.vy = 0; this.vx = 0;
    this.confused = false;
    this.colors = KITTEN_COLORS[playerId - 1];
    this.hitFlash = 0;
    this.dead = false;
  }

  applyPhysics(dt, terrain) {
    this.vy += 380 * dt;
    this.y  += this.vy * dt;
    this.x  += this.vx * dt;
    this.vx *= Math.max(0, 1 - 5 * dt);
    this.x   = Math.max(12, Math.min(CANVAS_W - 12, this.x));
    const ground = terrain.getHeightAt(this.x);
    if (this.y >= ground) { this.y = ground; this.vy = 0; }
    if (this.y >= WATER_Y) this.health = 0;
    if (this.hitFlash > 0) this.hitFlash -= dt * 4;
  }

  draw(ctx, isActive, myId) {
    const { x, y, colors, facing } = this;
    const flip = facing === 'left' ? -1 : 1;

    ctx.save();
    ctx.translate(x, y);
    ctx.scale(flip, 1);

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.22)';
    ctx.beginPath();
    ctx.ellipse(2, 1, 18, 4, 0, 0, Math.PI * 2);
    ctx.fill();

    // Hit flash
    if (this.hitFlash > 0) {
      ctx.filter = `brightness(${1 + this.hitFlash * 3})`;
    }

    // Body
    ctx.fillStyle = colors.body;
    ctx.beginPath(); ctx.ellipse(2, -10, 16, 12, 0, 0, Math.PI * 2); ctx.fill();
    // Belly
    ctx.fillStyle = colors.belly;
    ctx.beginPath(); ctx.ellipse(4, -8, 9, 8, 0.2, 0, Math.PI * 2); ctx.fill();
    // Stripes
    ctx.strokeStyle = colors.stripe; ctx.lineWidth = 1.5; ctx.globalAlpha = 0.5;
    [[-6,-18,-5,-4],[-2,-21,-1,-6],[3,-21,4,-5]].forEach(([x1,y1,x2,y2]) => {
      ctx.beginPath(); ctx.moveTo(x1,y1); ctx.lineTo(x2,y2); ctx.stroke();
    });
    ctx.globalAlpha = 1;
    // Head
    ctx.fillStyle = colors.body;
    ctx.beginPath(); ctx.arc(14,-22,13,0,Math.PI*2); ctx.fill();
    // Ears
    ctx.fillStyle = colors.body;
    ctx.beginPath(); ctx.moveTo(6,-33); ctx.lineTo(2,-44); ctx.lineTo(14,-37); ctx.fill();
    ctx.beginPath(); ctx.moveTo(18,-33); ctx.lineTo(24,-44); ctx.lineTo(28,-36); ctx.fill();
    ctx.fillStyle = '#ffb6c1';
    ctx.beginPath(); ctx.moveTo(8,-34); ctx.lineTo(5,-41); ctx.lineTo(13,-37); ctx.fill();
    ctx.beginPath(); ctx.moveTo(20,-34); ctx.lineTo(25,-41); ctx.lineTo(27,-37); ctx.fill();
    // Eyes
    ctx.filter = 'none';
    [[9,-24],[19,-24]].forEach(([ex,ey]) => {
      ctx.fillStyle='#fff'; ctx.beginPath(); ctx.arc(ex,ey,4.5,0,Math.PI*2); ctx.fill();
      ctx.fillStyle='#2d1a00'; ctx.beginPath(); ctx.arc(ex+0.5,ey,2.8,0,Math.PI*2); ctx.fill();
      ctx.fillStyle='#fff'; ctx.beginPath(); ctx.arc(ex+1.5,ey-1.5,1.2,0,Math.PI*2); ctx.fill();
    });
    // Nose + mouth
    ctx.fillStyle='#ff99b0';
    ctx.beginPath(); ctx.moveTo(14,-19); ctx.lineTo(11,-17); ctx.lineTo(17,-17); ctx.closePath(); ctx.fill();
    ctx.strokeStyle='#8a4a40'; ctx.lineWidth=1;
    ctx.beginPath(); ctx.moveTo(14,-17); ctx.quadraticCurveTo(10,-13,8,-14); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(14,-17); ctx.quadraticCurveTo(18,-13,20,-14); ctx.stroke();
    // Whiskers
    ctx.strokeStyle='rgba(255,255,255,0.7)'; ctx.lineWidth=0.8;
    [[-16,-22],[-15,-19],[-15,-16]].forEach(([ex,ey])=>{ctx.beginPath();ctx.moveTo(11,-19);ctx.lineTo(ex,ey);ctx.stroke();});
    [[24,-22],[23,-19],[23,-16]].forEach(([ex,ey])=>{ctx.beginPath();ctx.moveTo(17,-19);ctx.lineTo(ex,ey);ctx.stroke();});
    // Tail
    ctx.strokeStyle=colors.body; ctx.lineWidth=5; ctx.lineCap='round';
    ctx.beginPath(); ctx.moveTo(-14,-10); ctx.quadraticCurveTo(-30,8,-22,18); ctx.stroke();
    ctx.strokeStyle=colors.belly; ctx.lineWidth=3;
    ctx.beginPath(); ctx.arc(-22,15,6,0,Math.PI*2); ctx.stroke();

    ctx.restore();

    // Overhead health bar
    const bw=44, bx=x-22, by=y-60, pct=Math.max(0,this.health/100);
    ctx.fillStyle='rgba(0,0,0,0.6)';
    roundRect(ctx,bx-1,by-1,bw+2,10,3); ctx.fill();
    ctx.fillStyle=pct>0.5?'#4caf50':pct>0.25?'#ff9800':'#f44336';
    roundRect(ctx,bx,by,bw*pct,8,2); ctx.fill();

    ctx.font='bold 11px sans-serif';
    ctx.fillStyle = isActive ? '#ffd700' : '#aaa';
    ctx.textAlign='center';
    ctx.fillText(`P${this.playerId}`,x,by-3);
    if (myId===this.playerId) {
      ctx.font='9px sans-serif'; ctx.fillStyle='#79c0ff';
      ctx.fillText('YOU',x,by-14);
    }
    if (this.confused) { ctx.font='16px serif'; ctx.fillText('😵',x,by-25); }
  }
}

// ---- Game ----

class Game {
  constructor() {
    this.canvas = document.getElementById('game-canvas');
    this.ctx    = this.canvas.getContext('2d');
    this.state  = 'lobby';

    this.myPlayerId  = null;
    this.currentTurn = null;
    this.timeLeft    = 35;
    this.wind        = 0;

    this.terrain     = new Terrain(CANVAS_W);
    this.kittens     = [null, null];
    this.projectiles = [];
    this.laser       = null;
    this._laserDmg   = 0;
    this._laserTarget = null;

    this.particles   = new ParticleSystem();
    this.ui          = new UI(this.canvas);
    this.input       = new Input(this.canvas);
    this.network     = new Network();

    this.selectedWeapon = 'yarn';
    this.myAmmo      = {};
    this.movementLeft = MOVE_BUDGET;
    this.currentAim  = { angle: 0.3, power: 60 };
    this.statusMessage = '';
    this.statusTimer   = 0;
    this.confused      = false;
    this.screenShake   = 0;
    this.phase         = 'watching'; // watching | active | fired | laser
    this.turnEnded     = false;
    this.pendingShots  = 0;    // for scatter weapons
    this.shotResults   = { targetId: null, damage: 0, effect: null };

    this.lastTime = 0;
    this._setupNetwork();
    this._setupInput();
    requestAnimationFrame(t => this._loop(t));
  }

  // ======== Network ========

  _setupNetwork() {
    const net = this.network;

    net.on('welcome', msg => {
      this.myPlayerId = msg.playerId;
      const color     = msg.playerId===1 ? '#ff9944' : '#44aaff';
      const catName   = KITTEN_COLORS[msg.playerId-1].name;
      document.getElementById('lobby-status').textContent = 'Connected!';
      document.getElementById('lobby-info').classList.remove('hidden');
      document.getElementById('player-label').innerHTML =
        `<span style="color:${color}">Player ${msg.playerId} — ${catName} Tabby</span>`;
      if (msg.playerId===1 && msg.localIPs && msg.localIPs.length>0) {
        const urlBox = document.getElementById('share-url');
        urlBox.classList.remove('hidden');
        urlBox.innerHTML =
          `Share with Player 2:<br><strong>http://${msg.localIPs[0]}:${window.location.port||3000}</strong>`;
      }
    });

    net.on('waiting', () => {
      document.getElementById('lobby-status').textContent = 'Waiting for Player 2...';
    });

    net.on('game_start', msg => this._startGame(msg));
    net.on('turn_start', msg => this._startTurn(msg));
    net.on('time_up',    ()  => { this._showStatus("Time's up!"); this.phase='watching'; });

    net.on('fire', msg => {
      if (msg.from !== this.myPlayerId) {
        if (msg.weapon === 'laser') {
          this._showStatus('🔴 Opponent firing Laser Pointer!', 3.8);
        } else {
          this._executeFireMsg(msg, false);
        }
      }
    });

    net.on('health_update', msg => {
      // Server-authoritative health sync
      const k = this.kittens[msg.playerId-1];
      if (k) {
        const diff = k.health - msg.health;
        k.health = msg.health;
        if (diff > 0) this.particles.addText(k.x, k.y-55, `-${diff}`, '#f44336');
        if (k.health<=0) this._localDeath(k);
      }
    });

    net.on('game_over', msg => this._gameOver(msg));
    net.on('opponent_wants_rematch', () => this._showStatus('Opponent wants a rematch!'));
    net.on('opponent_left', msg => this._showDisconnect(msg.message||'Opponent left.'));
    net.on('disconnected',  ()  => this._showDisconnect('Connection lost.'));
    net.on('full', msg => {
      document.getElementById('lobby-status').textContent = msg.message||'Game is full!';
    });
    net.on('chat', msg => this._addChat(msg.from, msg.message));

    net.connect();
  }

  // ======== Input ========

  _setupInput() {
    document.addEventListener('keydown', e => {
      if (this.state !== 'playing') return;
      // Weapon hotkeys 1-8
      const idx = parseInt(e.key) - 1;
      if (idx >= 0 && idx < WEAPON_ORDER.length) {
        this.selectedWeapon = WEAPON_ORDER[idx];
      }
      if (e.code === 'KeyE' && this.isMyActiveTurn()) this._endTurn();
    });

    this.canvas.addEventListener('click', e => {
      if (this.state !== 'playing') return;
      const rect   = this.canvas.getBoundingClientRect();
      const scaleX = CANVAS_W / rect.width;
      const scaleY = CANVAS_H / rect.height;
      const mx = (e.clientX - rect.left) * scaleX;
      const my = (e.clientY - rect.top)  * scaleY;

      const panelY = CANVAS_H - PANEL_H;
      if (my >= panelY) {
        // Click in weapon panel — select slot
        const idx = Math.floor((mx - 10) / 110);
        if (idx >= 0 && idx < WEAPON_ORDER.length) this.selectedWeapon = WEAPON_ORDER[idx];
      } else if (this.isMyActiveTurn()) {
        this._handleFire();
      }
    });
  }

  // ======== Game loop ========

  _loop(ts) {
    const dt = Math.min((ts - this.lastTime) / 1000, 0.05);
    this.lastTime = ts;
    if (this.state === 'playing') this._update(dt);
    this._render();
    requestAnimationFrame(t => this._loop(t));
  }

  _update(dt) {
    this.input.update();

    // Timer
    if (this.phase === 'active') {
      this.timeLeft = Math.max(0, this.timeLeft - dt);
      if (this.timeLeft <= 0 && !this.turnEnded) this._endTurn();
    }

    // Active player movement
    if (this.isMyActiveTurn()) {
      const k = this.getMyKitten();
      if (k && this.movementLeft > 0) {
        let dx = 0;
        const leftKey  = this.confused ? this.input.isDown('right') : this.input.isDown('left');
        const rightKey = this.confused ? this.input.isDown('left')  : this.input.isDown('right');
        if (leftKey)  { dx=-1; k.facing=this.confused?'right':'left'; }
        if (rightKey) { dx= 1; k.facing=this.confused?'left':'right'; }
        if (dx !== 0) {
          const mv = Math.min(80*dt, this.movementLeft);
          k.x = Math.max(12, Math.min(CANVAS_W-12, k.x + dx*mv));
          k.y = this.terrain.getHeightAt(k.x);
          this.movementLeft -= mv;
        }
      }
      if (k) {
        const aim = this.input.getAimFromKitten(k);
        this.currentAim = aim;
      }
    }

    // Kitten physics (gravity, knockback)
    this.kittens.forEach(k => { if (k) k.applyPhysics(dt, this.terrain); });

    // Projectiles
    for (let i = this.projectiles.length-1; i >= 0; i--) {
      const p = this.projectiles[i];
      const hit = p.update(dt, this.terrain, this.kittens);
      if (hit) {
        this._handleHit(p, hit);
        this.projectiles.splice(i, 1);
      }
    }

    // Laser (only on active player's client for damage)
    if (this.laser && this.phase === 'laser') {
      const res = this.laser.update(dt, this.input.mouse.x, this.input.mouse.y, this.terrain, this.kittens);
      if (res && res.type === 'laser_hit') {
        const k = res.kitten;
        const dmg = res.damage;
        k.health = Math.max(0, k.health - dmg);
        k.hitFlash = 0.5;
        this.particles.addText(k.x, k.y-55, `-${dmg}`, '#f44336');
        this._laserDmg += dmg;
        this._laserTarget = k.playerId;
        if (k.health <= 0) this._localDeath(k);
      }
      if (this.laser && !this.laser.alive) {
        this.laser = null;
        this._reportShot(this._laserTarget, this._laserDmg, null);
      }
    }

    // Particles
    this.particles.update(dt);

    // Screen shake decay
    this.screenShake = this.screenShake > 0.3 ? this.screenShake*0.82 : 0;

    // Status timer
    if (this.statusTimer > 0) {
      this.statusTimer -= dt;
      if (this.statusTimer <= 0) this.statusMessage = '';
    }
  }

  // ======== Firing ========

  _handleFire() {
    if (!this.isMyActiveTurn() || this.phase !== 'active' || this.turnEnded) return;
    const weapon = WEAPONS[this.selectedWeapon];
    const ammo   = this.myAmmo[this.selectedWeapon];
    if (ammo !== undefined && ammo <= 0) {
      this._showStatus('Out of ammo!'); return;
    }
    const k = this.getMyKitten();
    if (!k) return;

    if (weapon.type === 'melee') {
      this._fireMelee(k, weapon); return;
    }
    if (weapon.type === 'laser') {
      this._fireLaser(k, weapon); return;
    }

    const { angle, power } = this.currentAim;

    // Pre-compute scatter angles so both clients see the same thing
    let projectiles;
    if (weapon.type === 'scatter') {
      projectiles = this._scatterAngles(weapon, angle, power);
    } else {
      projectiles = [{ angle, power }];
    }

    const msg = { type:'fire', weapon:this.selectedWeapon, x:k.x, y:k.y, projectiles };
    this.network.send(msg);
    this._executeFireMsg({ ...msg, from: this.myPlayerId }, true);
  }

  _scatterAngles(weapon, baseAngle, basePower) {
    const count  = weapon.count  || 3;
    const spread = weapon.spread || 0.3;
    const arr = [];
    for (let i = 0; i < count; i++) {
      arr.push({
        angle: baseAngle + (Math.random()-0.5) * spread * 2,
        power: basePower * (0.8 + Math.random()*0.4)
      });
    }
    return arr;
  }

  _executeFireMsg(msg, isMe) {
    const weapon    = WEAPONS[msg.weapon];
    const enemy     = isMe ? this._enemyKitten() : this.getMyKitten();
    const fromKitten = isMe ? this.getMyKitten() : this._enemyKitten();
    if (!fromKitten) return;

    if (isMe) {
      this.phase       = 'fired';
      this.pendingShots = msg.projectiles.length;
      this.shotResults  = { targetId:null, damage:0, effect:null };
    }

    msg.projectiles.forEach(({ angle, power }) => {
      const proj = new Projectile(fromKitten.x, fromKitten.y-22, angle, power, weapon, this.wind, this.terrain, enemy);
      this.projectiles.push(proj);
    });
  }

  _fireMelee(k, weapon) {
    const enemy = this._enemyKitten();
    if (!enemy) return;
    const dist = Math.abs(enemy.x - k.x);
    if (dist > weapon.range) {
      this._showStatus(`Too far away! Need <${weapon.range}px`); return;
    }
    const ang = Math.atan2(enemy.y - k.y, enemy.x - k.x);
    const msg = { type:'fire', weapon:this.selectedWeapon, x:k.x, y:k.y,
                  projectiles:[{ angle:ang, power:60 }] };
    this.network.send(msg);
    this._executeFireMsg({ ...msg, from:this.myPlayerId }, true);
  }

  _fireLaser(k, weapon) {
    this.laser        = new LaserBeam(k.x, k.y-22, weapon);
    this._laserDmg    = 0;
    this._laserTarget = null;
    this.phase        = 'laser';
    const msg = { type:'fire', weapon:this.selectedWeapon, x:k.x, y:k.y, projectiles:[] };
    this.network.send(msg);
    // Passive player sees "(Opponent is using Laser Pointer!)" via status
  }

  // ======== Hit resolution ========

  _handleHit(proj, result) {
    const weapon = proj.weapon;
    const hx = result.x, hy = result.y;

    if (result.type !== 'oob') {
      if (weapon.radius > 0) {
        this.terrain.carve(Math.floor(hx), Math.floor(hy), weapon.radius);
        this.particles.explode(hx, hy, weapon.radius, weapon.color);
        this.screenShake = weapon.radius * 0.28;
      } else {
        this.particles.dust(hx, hy, 8);
      }

      // Damage
      let hitTargetId = null, totalDamage = 0, effect = null;
      this.kittens.forEach(k => {
        if (!k) return;
        const dx = k.x - hx, dy = (k.y-20) - hy;
        const dist = Math.sqrt(dx*dx+dy*dy);
        const hitR  = Math.max(weapon.radius||0, 22);
        if (dist < hitR) {
          const dmg = weapon.type==='melee'
            ? weapon.damage
            : Math.round(weapon.damage * Math.max(0, 1-dist/hitR));
          if (dmg > 0) {
            k.health   = Math.max(0, k.health - dmg);
            k.hitFlash = 1;
            this.particles.addText(k.x, k.y-55, `-${dmg}`, '#f44336');
            totalDamage = dmg;
            hitTargetId = k.playerId;
            // Knockback
            const kf = weapon.knockback || weapon.radius*3.5 || 80;
            if (dist > 0) { k.vx=(dx/dist)*kf; k.vy=(dy/dist)*kf-100; }
            if (weapon.effect==='confused') {
              effect = 'confused';
              this.particles.addText(k.x, k.y-78, '😵 CONFUSED!', '#ff9800');
            }
            if (k.health<=0) this._localDeath(k);
          }
        }
      });

      // Accumulate for scatter weapons
      if (this.myPlayerId === this.currentTurn) {
        if (hitTargetId) {
          this.shotResults.targetId = hitTargetId;
          this.shotResults.damage  += totalDamage;
          if (effect) this.shotResults.effect = effect;
        }
      }
    }

    // Decrement pending shot counter
    if (this.myPlayerId === this.currentTurn && this.phase === 'fired') {
      this.pendingShots--;
      if (this.pendingShots <= 0) {
        const { targetId, damage, effect } = this.shotResults;
        this._reportShot(targetId, damage, effect);
      }
    }
  }

  _reportShot(targetId, damage, effect) {
    if (this.turnEnded) return;
    this.turnEnded = true;
    this.network.send({ type:'shot_complete', targetId, damage, effect });
    this.phase = 'watching';
  }

  _endTurn() {
    if (this.turnEnded) return;
    this.turnEnded = true;
    this.network.send({ type:'end_turn' });
    this.phase = 'watching';
  }

  _localDeath(k) {
    if (k.dead) return;
    k.dead = true;
    this.particles.confetti(k.x, k.y, ['#ff6b9d','#ffd700','#ff6b6b','#79c0ff','#4caf50']);
    this.particles.addText(k.x, k.y-80, 'KO!', '#ffd700');
  }

  // ======== Game-state handlers ========

  _startGame(msg) {
    this.state = 'playing';
    document.getElementById('lobby').classList.add('hidden');
    document.getElementById('gameover').classList.add('hidden');

    this.terrain.generate(msg.seed);
    this.wind = msg.wind;

    const x1 = 190, x2 = CANVAS_W-190;
    this.kittens[0] = new Kitten(x1, this.terrain.getHeightAt(x1), 1);
    this.kittens[1] = new Kitten(x2, this.terrain.getHeightAt(x2), 2);

    this.projectiles = [];
    this.laser       = null;
    this.particles   = new ParticleSystem();
    this.phase       = 'watching';
    this.turnEnded   = false;
    this._showStatus('Game Start! 🐱', 2.5);
  }

  _startTurn(msg) {
    this.currentTurn  = msg.playerId;
    this.timeLeft     = msg.timeLeft;
    this.wind         = msg.wind;
    const ammoKey = `ammoP${this.myPlayerId}`;
    this.myAmmo   = msg[ammoKey] || this.myAmmo;
    this.movementLeft = MOVE_BUDGET;
    this.turnEnded    = false;
    this.pendingShots = 0;
    this.shotResults  = { targetId:null, damage:0, effect:null };

    const activeK = this.kittens[msg.playerId-1];
    if (activeK) activeK.confused = msg.confused || false;
    this.confused = (msg.playerId===this.myPlayerId) && (msg.confused||false);

    if (msg.playerId === this.myPlayerId) {
      this.phase = 'active';
      this._showStatus(this.confused ? 'Your Turn! 😵 (Controls reversed!)' : 'Your Turn!', 2);
    } else {
      this.phase = 'watching';
      this._showStatus("Opponent's Turn...", 1.5);
    }
  }

  _gameOver(msg) {
    this.state = 'gameover';
    const won = msg.winner === this.myPlayerId;
    document.getElementById('winner-text').textContent = won ? 'You Win! 🎉' : 'You Lost! 😿';
    document.getElementById('winner-sub').textContent  = won
      ? 'Your kitten reigns supreme!' : 'Better luck next time...';
    document.getElementById('gameover').classList.remove('hidden');
    if (won) this.particles.confetti(CANVAS_W/2, CANVAS_H/2,
      ['#ff6b9d','#ffd700','#ff6b6b','#4caf50','#79c0ff']);
  }

  requestRematch() {
    this.network.send({ type:'rematch' });
    document.getElementById('waiting-rematch').classList.remove('hidden');
    document.getElementById('rematch-btn').disabled = true;
  }

  // ======== Helpers ========

  isMyActiveTurn() {
    return this.state==='playing' && this.currentTurn===this.myPlayerId && this.phase==='active';
  }

  getMyKitten()  { return this.myPlayerId ? this.kittens[this.myPlayerId-1] : null; }
  _enemyKitten() { return this.myPlayerId ? this.kittens[this.myPlayerId===1?1:0] : null; }

  _showStatus(msg, dur=2.2) { this.statusMessage=msg; this.statusTimer=dur; }

  _showDisconnect(msg) {
    document.getElementById('disconnect-msg').textContent = msg;
    document.getElementById('disconnected').classList.remove('hidden');
  }

  _addChat(from, text) {
    const el  = document.getElementById('chat-messages');
    const div = document.createElement('div');
    div.className = `chat-msg p${from}`;
    div.textContent = `P${from}: ${text}`;
    el.appendChild(div);
    setTimeout(() => div.remove(), 4500);
  }

  // ======== Render ========

  _render() {
    const { ctx } = this;
    ctx.save();
    if (this.screenShake > 0) {
      ctx.translate((Math.random()-0.5)*this.screenShake*2, (Math.random()-0.5)*this.screenShake*2);
    }

    this.ui.drawBackground(ctx, CANVAS_W, CANVAS_H);

    if (this.state==='playing' || this.state==='gameover') {
      this.terrain.draw(ctx);
      this.ui.drawWater(ctx, CANVAS_W);
      this.kittens.forEach((k,i) => { if (k) k.draw(ctx, this.currentTurn===i+1, this.myPlayerId); });
      this.projectiles.forEach(p => p.draw(ctx));
      if (this.laser) this.laser.draw(ctx);
      this.particles.draw(ctx);
      if (this.state==='playing') this.ui.drawHUD(ctx, this);
    }

    ctx.restore();
  }
}

window.addEventListener('load', () => { window.game = new Game(); });
