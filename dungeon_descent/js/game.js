'use strict';

// ===========================
// GAME STATES
// ===========================
const STATE = {
  MENU:      'menu',
  PLAYING:   'playing',
  UPGRADE:   'upgrade',
  PAUSED:    'paused',
  GAME_OVER: 'game_over',
  VICTORY:   'victory',
  TRANSITION:'transition',
};

// ===========================
// GAME
// ===========================
const Game = {
  canvas: null,
  ctx: null,
  state: STATE.MENU,
  lastTime: 0,
  anim: 0,

  // Game world
  floor: 1,
  dungeon: null,
  player: null,
  enemies: [],
  projectiles: [],
  items: [],  // {x, y, type:'coin'|'heart', value, anim, life}
  boss: null,

  // Upgrade state
  upgradeChoices: [],
  upgradeHover: 0,
  upgradeOpenTime: 0,

  // Room transition
  transitionDir: null,
  transitionT: 0,

  // Room clear flash
  clearFlash: 0,

  // Floor history (for pit falls back to previous floor)
  floorHistory: [],
  floorFlash: 1,

  // Stats
  totalRooms: 0,
  clearedRooms: 0,

  init() {
    this.canvas = document.getElementById('game');
    this.canvas.width  = C.W;
    this.canvas.height = C.H;
    this.ctx = this.canvas.getContext('2d');
    this.ctx.imageSmoothingEnabled = false;

    Input.init(this.canvas);
    Audio.init();

    rngSeed(Date.now());

    this.canvas.addEventListener('click', () => {
      Audio.resume();
      this._handleClick();
    });

    requestAnimationFrame(t => this._loop(t));
  },

  _handleClick() {
    if (this.state === STATE.MENU)      this._startGame();
    else if (this.state === STATE.GAME_OVER || this.state === STATE.VICTORY) this._startGame();
    else if (this.state === STATE.UPGRADE) {
      if (Date.now() - this.upgradeOpenTime >= 500) this._selectUpgrade(this.upgradeHover);
    }
  },

  _startGame() {
    rngSeed(Date.now());
    this.floor = 1;
    this.floorHistory = [];
    this.floorFlash = 1;
    this.player = new Player();
    this._loadDungeon();
    this.state = STATE.PLAYING;
    Audio.resume();
  },

  _loadDungeon() {
    this.dungeon = new Dungeon(this.floor);
    this.projectiles = [];
    this.items = [];
    this.boss = null;
    Particles.clear();

    const room = this.dungeon.startRoom;
    this.dungeon.currentRoom = room;
    this.player.x = C.VW / 2;
    this.player.y = C.VH / 2;

    this.totalRooms = Object.values(this.dungeon.rooms).filter(r => r.type !== RTYPE.START).length;
    this.clearedRooms = 0;

    this._populateRoom(room);
  },

  _populateRoom(room) {
    this.enemies = [];
    this.projectiles = [];
    if (room.enemies.length > 0) {
      this.enemies = room.enemies;
    } else if (!room.cleared) {
      this.enemies = spawnEnemies(room, this.floor);
      room.enemies = this.enemies;
      if (room.type === RTYPE.BOSS) {
        this.boss = this.enemies.find(e => e instanceof Boss) || null;
        if (this.boss) Audio.play('boss_enter');
      }
      if (this.enemies.length > 0) room.closeDoors();
    }

    // Chest
    if ((room.type === RTYPE.TREASURE || room.type === RTYPE.BOSS) && !room.chestOpened && !room.chest) {
      const cp = room.chestPos();
      room.chest = { x: cp.x, y: cp.y };
    }

    // Preplace items (shop)
    if (room.type === RTYPE.SHOP && !room.cleared) {
      room.cleared = true; // shops don't need clearing
      room.openDoors();
    }
  },

  _ascendFloor() {
    this.floorHistory.push({
      dungeon: this.dungeon,
      floor: this.floor,
      clearedRooms: this.clearedRooms,
      totalRooms: this.totalRooms,
    });
    this.floor++;
    this.projectiles = [];
    this.items = [];
    this.boss = null;
    Particles.clear();

    this.dungeon = new Dungeon(this.floor);
    const room = this.dungeon.startRoom;
    this.dungeon.currentRoom = room;
    this.player.x = C.VW / 2;
    this.player.y = C.VH / 2;
    this.totalRooms = Object.values(this.dungeon.rooms).filter(r => r.type !== RTYPE.START).length;
    this.clearedRooms = 0;
    this._populateRoom(room);

    this.floorFlash = 0;
    Audio.play('stair_up');
  },

  _descendFloor() {
    const saved = this.floorHistory.pop();
    if (!saved) return;

    this.floor = saved.floor;
    this.dungeon = saved.dungeon;
    this.clearedRooms = saved.clearedRooms;
    this.totalRooms = saved.totalRooms;
    this.projectiles = [];
    this.items = [];
    this.boss = null;
    Particles.clear();

    // Land in a random cleared+visited room from the restored floor
    const rooms = Object.values(saved.dungeon.rooms).filter(r => r.visited && r.cleared);
    const landRoom = rooms.length > 0 ? rPick(rooms) : saved.dungeon.startRoom;
    saved.dungeon.currentRoom = landRoom;

    const pts = landRoom.spawnPoints();
    const pt = pts.length > 0 ? pts[rInt(0, Math.min(pts.length - 1, 4))] : null;
    this.player.x = pt ? pt.x : C.VW / 2;
    this.player.y = pt ? pt.y : C.VH / 2;
    this.enemies = landRoom.enemies.filter(e => !e.dead);

    this.floorFlash = 0;
    CameraShake.shake(4, 0.3);
    Audio.play('pit_fall');
  },

  _checkStairs() {
    const room = this.dungeon.currentRoom;
    if (!room.hasStairs) return;
    const tx = Math.floor(this.player.x / C.TS);
    const ty = Math.floor(this.player.y / C.TS);
    if (isStairs(room.getTile(tx, ty)) && (Input.just('KeyE') || Input.just('Enter'))) {
      this._ascendFloor();
    }
  },

  _checkPit() {
    if (!this.floorHistory.length || this.floorFlash < 1) return;
    const room = this.dungeon.currentRoom;
    const tx = Math.floor(this.player.x / C.TS);
    const ty = Math.floor(this.player.y / C.TS);
    if (isPit(room.getTile(tx, ty))) {
      this._descendFloor();
    }
  },

  _enterRoom(room, fromDir) {
    if (!room) return;
    const prev = this.dungeon.currentRoom;
    this.dungeon.currentRoom = room;
    room.visited = true;

    // Position player at door entry
    const mx = Math.floor(C.RW / 2) * C.TS + C.TS / 2;
    const my = Math.floor(C.RH / 2) * C.TS + C.TS / 2;
    const margin = C.TS * 1.5;

    switch (fromDir) {
      case 'n': this.player.x = mx; this.player.y = C.VH - margin; break;
      case 's': this.player.x = mx; this.player.y = margin; break;
      case 'e': this.player.x = margin; this.player.y = my; break;
      case 'w': this.player.x = C.VW - margin; this.player.y = my; break;
    }

    this._populateRoom(room);
    Audio.play('door_open');
  },

  _checkDoorTransition() {
    const player = this.player;
    const room = this.dungeon.currentRoom;
    const margin = 8;

    const tryEnter = (dir, nextRoom, condition) => {
      if (!nextRoom || !condition) return;
      // Door must be open
      let doorOpen = false;
      if (dir === 'n' || dir === 's') {
        const mx = Math.floor(C.RW/2);
        const ty = dir === 'n' ? 0 : C.RH - 1;
        doorOpen = isOpenDoor(room.getTile(mx - 1, ty)) || isOpenDoor(room.getTile(mx, ty));
      } else {
        const my = Math.floor(C.RH/2);
        const tx = dir === 'e' ? C.RW - 1 : 0;
        doorOpen = isOpenDoor(room.getTile(tx, my));
      }
      if (doorOpen) {
        this._enterRoom(nextRoom, dir);
      }
    };

    tryEnter('n', room.connections.n, player.y < margin);
    tryEnter('s', room.connections.s, player.y > C.VH - margin);
    tryEnter('e', room.connections.e, player.x > C.VW - margin);
    tryEnter('w', room.connections.w, player.x < margin);
  },

  _checkRoomClear() {
    const room = this.dungeon.currentRoom;
    if (room.cleared || this.enemies.some(e => !e.dead)) return;

    room.cleared = true;
    room.openDoors();
    this.clearFlash = 0;
    Audio.play('door_open');
    Particles.magic(C.VW/2, C.VH/2);

    this.clearedRooms++;
    this.player.roomsCleared++;

    // Drop rewards
    const pts = room.spawnPoints().slice(0, 4);
    // Coins from enemies are already dropped on kill
    // Extra coin from cleared room
    if (pts.length > 0) {
      const cp = pts[0];
      this._dropCoins(cp.x, cp.y, 2 + this.player.luck);
    }

    // Chest for treasure/boss rooms
    if (room.type === RTYPE.TREASURE || room.type === RTYPE.BOSS) {
      if (!room.chestOpened) {
        const cp = room.chestPos();
        room.chest = { x: cp.x, y: cp.y };
      }
    }

    // Offer upgrade after every cleared enemy room (except boss)
    if (room.type === RTYPE.NORMAL && this.enemies.length > 0) {
      if (this.player.roomsCleared % 1 === 0) {
        this._showUpgrades();
        return;
      }
    }

    // Boss cleared — show upgrade choices (victory/stairs handled in _selectUpgrade)
    if (room.type === RTYPE.BOSS) {
      const boss = this.enemies.find(e => e instanceof Boss);
      if (boss && boss.dead) {
        setTimeout(() => { this._showUpgrades(4); }, 1500);
      }
    }
  },

  _showUpgrades(count) {
    this.upgradeChoices = Upgrades.buildPool(this.player, count || 3);
    if (!this.upgradeChoices.length) return;
    this.upgradeHover = 0;
    this.upgradeOpenTime = Date.now();
    this.state = STATE.UPGRADE;
    Audio.play('upgrade');
  },

  _selectUpgrade(idx) {
    if (idx < 0 || idx >= this.upgradeChoices.length) return;
    const choice = this.upgradeChoices[idx];
    this.player.addUpgrade(choice.id);
    Particles.magic(this.player.x, this.player.y);
    Audio.play('upgrade');

    const room = this.dungeon.currentRoom;
    if (room && room.type === RTYPE.BOSS) {
      if (this.floor >= C.MAX_FLOORS) {
        this.state = STATE.VICTORY;
      } else {
        room.placeStairs();
        this.state = STATE.PLAYING;
      }
    } else {
      this.state = STATE.PLAYING;
    }
  },

  _dropCoins(x, y, count) {
    for (let i = 0; i < count; i++) {
      this.items.push({
        x: x + rFloat(-12, 12),
        y: y + rFloat(-8, 8),
        type: 'coin',
        value: 1,
        anim: rFloat(0, 10),
        life: 30,
      });
    }
    Particles.coin(x, y);
  },

  _dropHeart(x, y) {
    this.items.push({
      x, y, type: 'heart', value: 2,
      anim: 0, life: 30,
    });
  },

  _onEnemyDied(enemy) {
    this.player.kills++;
    this.player.gainXP(enemy.xp);
    Audio.play('kill');

    // Drop coins
    if (enemy.coins > 0) this._dropCoins(enemy.x, enemy.y, enemy.coins);
    // Rare heart drop (higher luck = more chance)
    if (Math.random() < 0.05 + this.player.luck * 0.02) {
      this._dropHeart(enemy.x, enemy.y);
    }

    // Lifesteal upgrade
    if (this.player.hasUpgrade('lifesteal')) this.player.heal(1);

    // Soul rend stacks
    if (this.player.hasUpgrade('soul_rend')) {
      this.player.soulStacks = Math.min(5, this.player.soulStacks + 1);
      this.player.soulTimer = 8;
    }

    // Explosive finale
    if (this.player.hasUpgrade('explosive_finale')) {
      Particles.explosion(enemy.x, enemy.y);
      Audio.play('explosion');
      for (const e of this.enemies) {
        if (e !== enemy && !e.dead && dist(e.x, e.y, enemy.x, enemy.y) < 32) {
          e.takeDamage(3, enemy.x, enemy.y);
        }
      }
    }

    // Slime splits
    if (enemy.splitChildren) {
      for (const pos of enemy.splitChildren) {
        const small = new Slime(pos.x, pos.y, this.floor, true);
        this.enemies.push(small);
      }
      enemy.splitChildren = null;
    }
  },

  _updateItems(dt) {
    const room = this.dungeon.currentRoom;
    const player = this.player;
    const magnetRange = player.hasUpgrade('coin_magnet') ? 40 : 12;

    this.items = this.items.filter(item => {
      item.anim += dt;
      item.life -= dt;
      if (item.life <= 0) return false;

      // Attract to player
      const d = dist(item.x, item.y, player.x, player.y);
      if (d < magnetRange) {
        const n = norm(player.x - item.x, player.y - item.y);
        item.x += n.x * 80 * dt;
        item.y += n.y * 80 * dt;
      }

      // Collect
      if (d < 8) {
        if (item.type === 'coin') {
          player.coins += item.value;
          Particles.coin(item.x, item.y);
          Particles.goldGain(player.x, player.y - 10, item.value);
          Audio.play('coin');
        } else if (item.type === 'heart') {
          player.heal(item.value);
        }
        return false;
      }
      return true;
    });

    // Check chest interaction
    if (room.chest && !room.chestOpened) {
      const chest = room.chest;
      const d = dist(player.x, player.y, chest.x + 6, chest.y + 5);
      if (d < 16 && (Input.just('KeyE') || Input.just('Enter') || Input.mouse.leftDown)) {
        room.chestOpened = true;
        Audio.play('chest');
        Particles.magic(chest.x + 6, chest.y);
        Particles.coin(chest.x + 6, chest.y + 5);
        // Treasure: 3+ coins + upgrade
        this._dropCoins(chest.x + 6, chest.y + 5, 5 + this.floor);
        this._showUpgrades(3);
      }
    }
  },

  _updateOrbitShield(dt, enemies) {
    if (!this.player.hasUpgrade('orbit_shield')) return;
    const t = this.anim;
    for (let i = 0; i < 2; i++) {
      const a = t * 2 + i * Math.PI;
      const sx = this.player.x + Math.cos(a) * 12;
      const sy = this.player.y + Math.sin(a) * 8;
      // Block enemy projectiles
      this.projectiles = this.projectiles.filter(p => {
        if (p.owner === 'enemy' && dist(p.x, p.y, sx, sy) < 5) {
          Particles.hit(p.x, p.y, C.COL.SHIELD_FG);
          return false;
        }
        return true;
      });
    }
  },

  _updateThorns(enemies) {
    if (!this.player.hasUpgrade('thorns')) return;
    const thornsDmg = this.player.upgradeLevel('thorns');
    for (const e of enemies) {
      if (e.dead) continue;
      if (dist(e.x, e.y, this.player.x, this.player.y) < e.size + C.P_SIZE + 2) {
        // Only tick once per contact (use e.thornsTick)
        if (!e._thornsTick) {
          e.takeDamage(thornsDmg, this.player.x, this.player.y);
          e._thornsTick = true;
          setTimeout(() => { e._thornsTick = false; }, 500);
        }
      }
    }
  },

  _update(dt) {
    this.anim += dt;
    CameraShake.update(dt);

    const room = this.dungeon.currentRoom;
    const player = this.player;

    // Update player
    player.update(dt, room, this.projectiles);

    // Sword hits
    const hitEnemies = player.doSwordHit(this.enemies, room);
    for (const e of hitEnemies) {
      CameraShake.shake(2, 0.08);
      if (e.dead) this._onEnemyDied(e);
    }

    // Player took damage
    if (player.hp <= 0) {
      this.state = STATE.GAME_OVER;
      Audio.play('death');
      Particles.death(player.x, player.y, C.COL.PLAYER);
      return;
    }

    // Update enemies
    const bossRef = { summonCb: null };
    bossRef.summonCb = () => {
      const pts = room.spawnPoints().slice(0, 2);
      for (const p of pts) {
        const e = new Slime(p.x, p.y, this.floor, false);
        this.enemies.push(e);
      }
    };

    for (const enemy of this.enemies) {
      if (enemy.dead) continue;
      if (enemy instanceof Boss) {
        enemy.update(dt, player, room, this.projectiles, bossRef.summonCb);
      } else {
        enemy.update(dt, player, room, this.projectiles);
      }
      if (enemy.dead) this._onEnemyDied(enemy);
    }

    // Update projectiles
    const activeEnemies = this.enemies.filter(e => !e.dead);
    for (const p of this.projectiles) {
      p.update(dt, room, activeEnemies, player);
    }
    this.projectiles = this.projectiles.filter(p => p.alive);

    // Player damage from proj
    if (player.hp <= 0) {
      this.state = STATE.GAME_OVER;
      Audio.play('death');
      return;
    }

    // Orbit shield
    this._updateOrbitShield(dt, activeEnemies);
    this._updateThorns(activeEnemies);

    // Items
    this._updateItems(dt);

    // Boss tracker
    if (room.type === RTYPE.BOSS) {
      this.boss = this.enemies.find(e => e instanceof Boss) || null;
    } else {
      this.boss = null;
    }

    // Particles
    Particles.update(dt);

    // Clear flash
    if (this.clearFlash < 1) this.clearFlash = Math.min(1, this.clearFlash + dt * 2);

    // Room clear check
    this._checkRoomClear();

    // Door transition
    this._checkDoorTransition();

    // Stair / pit transitions
    this._checkStairs();
    this._checkPit();

    // Floor flash animation
    if (this.floorFlash < 1) this.floorFlash = Math.min(1, this.floorFlash + dt * 2.5);

    // Keyboard input for upgrades
    if (Input.wantPause()) {
      this.state = STATE.PAUSED;
    }
    if (Input.just('KeyM')) Audio.toggle();
  },

  _drawRoom(ctx) {
    const room = this.dungeon.currentRoom;
    renderRoom(ctx, room);

    // Draw chest
    if (room.chest) {
      drawChest(ctx, room.chest.x, room.chest.y, room.chestOpened);
      if (!room.chestOpened) {
        // Interaction hint
        const d = dist(this.player.x, this.player.y, room.chest.x+6, room.chest.y+5);
        if (d < 20) {
          drawTextShadow(ctx, '[E] Open', room.chest.x + 6, room.chest.y - 4, 4, '#ffffff', '#000');
        }
      }
    }

    // Draw stair tile interaction hint
    if (room.hasStairs) {
      const sx = Math.floor(C.RW / 2) * C.TS + C.TS / 2;
      const sy = Math.floor(C.RH / 2) * C.TS + C.TS / 2;
      if (dist(this.player.x, this.player.y, sx, sy) < 28) {
        drawTextShadow(ctx, '[E] Ascend', sx, sy - 14, 4, '#80c0ff', '#000');
      }
    }

    // Draw items
    for (const item of this.items) {
      if (item.type === 'coin') {
        drawCoin(ctx, item.x, item.y, item.anim);
      } else if (item.type === 'heart') {
        ctx.fillStyle = C.COL.HEART;
        ctx.font = '8px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('♥', item.x, item.y);
      }
    }
  },

  _draw() {
    const ctx = this.ctx;

    // Clear
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, C.W, C.H);

    // Scale to virtual resolution with camera shake
    ctx.save();
    ctx.scale(C.S, C.S);
    ctx.translate(Math.round(CameraShake.x), Math.round(CameraShake.y));

    if (this.state === STATE.MENU) {
      renderMainMenu(ctx, this.anim);
      ctx.restore();
      return;
    }

    if (this.state === STATE.GAME_OVER) {
      renderGameOver(ctx, this.player, this.floor, this.anim);
      ctx.restore();
      return;
    }

    if (this.state === STATE.VICTORY) {
      renderVictory(ctx, this.player, this.floor, this.anim);
      ctx.restore();
      return;
    }

    // === PLAYING / UPGRADE / PAUSED ===
    // Background
    ctx.fillStyle = C.COL.BG;
    ctx.fillRect(0, 0, C.VW, C.VH);

    // Room
    this._drawRoom(ctx);

    // Enemies (draw back-to-front by Y)
    const sortedEnemies = [...this.enemies].sort((a, b) => a.y - b.y);
    for (const e of sortedEnemies) {
      if (!e.dead) e.draw(ctx);
    }

    // Player (in Y-sort position)
    this.player.draw(ctx);

    // Projectiles
    for (const p of this.projectiles) p.draw(ctx);

    // Particles
    Particles.draw(ctx);

    // Room type label (brief)
    const room = this.dungeon?.currentRoom;
    if (room && !room.cleared) {
      if (room.type === RTYPE.BOSS) {
        renderBossBar(ctx, this.boss);
      }
      const enemiesLeft = this.enemies.filter(e => !e.dead).length;
      if (enemiesLeft > 0) {
        drawTextShadow(ctx, `${enemiesLeft} enemy${enemiesLeft>1?'s':''} remaining`, C.VW/2, 8, 5, C.COL.UI_DIM, '#000');
      }
    }

    // Floor transition flash
    if (this.floorFlash < 1) {
      ctx.globalAlpha = (1 - this.floorFlash) * 0.75;
      ctx.fillStyle = '#b8d8ff';
      ctx.fillRect(0, 0, C.VW, C.VH);
      ctx.globalAlpha = 1;
    }

    // HUD
    renderHUD(ctx, this.player, this.dungeon, this.floor, this.clearedRooms, this.totalRooms);

    // Overlays
    if (this.state === STATE.UPGRADE) {
      renderUpgradeScreen(ctx, this.upgradeChoices, this.upgradeHover, this.anim,
        Date.now() - this.upgradeOpenTime >= 500);
    } else if (this.state === STATE.PAUSED) {
      renderPause(ctx, this.player, this.anim);
    }

    ctx.restore();
  },

  _handleInputs() {
    if (this.state === STATE.MENU) {
      if (Input.just('Enter') || Input.just('Space')) this._startGame();
    } else if (this.state === STATE.GAME_OVER || this.state === STATE.VICTORY) {
      if (Input.just('Enter') || Input.just('Space')) this._startGame();
    } else if (this.state === STATE.PAUSED) {
      if (Input.wantPause()) this.state = STATE.PLAYING;
      if (Input.just('KeyM')) Audio.toggle();
    } else if (this.state === STATE.UPGRADE) {
      const n = this.upgradeChoices.length;
      const canSelect = Date.now() - this.upgradeOpenTime >= 500;

      if (canSelect) {
        if (Input.just('ArrowLeft')  || Input.just('KeyA')) this.upgradeHover = (this.upgradeHover - 1 + n) % n;
        if (Input.just('ArrowRight') || Input.just('KeyD')) this.upgradeHover = (this.upgradeHover + 1) % n;
        if (Input.just('Enter') || Input.just('KeyE') || Input.just('Space')) {
          this._selectUpgrade(this.upgradeHover);
        }
        for (let i = 0; i < n; i++) {
          if (Input.just(`Digit${i+1}`)) { this._selectUpgrade(i); break; }
        }
      }

      // Mouse hover always active so the player can read cards during the delay
      const cardW = 80, gap = 10;
      const totalW = n * cardW + (n - 1) * gap;
      const startX = (C.VW - totalW) / 2;
      const mx = Input.mouse.x, my = Input.mouse.y;
      for (let i = 0; i < n; i++) {
        const cx = startX + i * (cardW + gap);
        if (mx >= cx && mx <= cx + cardW && my >= 50 && my <= 160) {
          this.upgradeHover = i;
          break;
        }
      }
    }
  },

  _loop(timestamp) {
    const dt = Math.min((timestamp - this.lastTime) / 1000, 0.05);
    this.lastTime = timestamp;

    this._handleInputs();

    if (this.state === STATE.PLAYING) {
      this._update(dt);
    }

    this._draw();

    Input.update();
    requestAnimationFrame(t => this._loop(t));
  },
};

// Boot
window.addEventListener('load', () => Game.init());
