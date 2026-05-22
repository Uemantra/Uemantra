const PANEL_H = 90;

class UI {
  constructor(canvas) {
    this.canvas = canvas;
    this.W = canvas.width;
    this.H = canvas.height;
  }

  drawHUD(ctx, game) {
    this._drawTopBar(ctx, game);
    this._drawBottomPanel(ctx, game);
    if (game.isMyActiveTurn()) {
      this._drawAimIndicator(ctx, game);
    }
    this._drawStatusLabels(ctx, game);
  }

  _drawTopBar(ctx, game) {
    const W = this.W;
    // Semi-transparent bar
    ctx.fillStyle = 'rgba(0,0,0,0.55)';
    ctx.fillRect(0, 0, W, 58);

    // Player 1
    const p1 = game.kittens[0];
    if (p1) this._drawHealthBar(ctx, 16, 8, p1.health, 'P1  ' + (game.myPlayerId === 1 ? '(You)' : ''), '#ff9944', game.currentTurn === 1, p1.confused);

    // Player 2
    const p2 = game.kittens[1];
    if (p2) this._drawHealthBar(ctx, W - 230, 8, p2.health, 'P2  ' + (game.myPlayerId === 2 ? '(You)' : ''), '#44aaff', game.currentTurn === 2, p2.confused);

    // Center: timer + wind
    this._drawTimer(ctx, W / 2, 4, game.timeLeft, 35);
    this._drawWind(ctx, W / 2 - 60, 38, game.wind);
  }

  _drawHealthBar(ctx, x, y, health, label, color, active, confused) {
    const bw = 210;
    const bh = 18;

    // Background
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    roundRect(ctx, x, y + 16, bw, bh, 4);
    ctx.fill();

    // Health fill
    const pct = Math.max(0, health / 100);
    const hColor = pct > 0.5 ? '#4caf50' : pct > 0.25 ? '#ff9800' : '#f44336';
    ctx.fillStyle = hColor;
    roundRect(ctx, x + 2, y + 18, (bw - 4) * pct, bh - 4, 3);
    ctx.fill();

    // HP text
    ctx.font = 'bold 12px monospace';
    ctx.fillStyle = '#fff';
    ctx.textAlign = 'center';
    ctx.fillText(`${Math.ceil(health)} HP`, x + bw / 2, y + 29);

    // Label
    ctx.font = active ? 'bold 13px sans-serif' : '12px sans-serif';
    ctx.fillStyle = active ? color : '#aaa';
    ctx.textAlign = 'left';
    ctx.fillText(label + (confused ? ' 😵' : ''), x, y + 12);

    // Active indicator
    if (active) {
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(x - 8, y + 24, 5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  _drawTimer(ctx, cx, y, timeLeft, maxTime) {
    const pct = Math.max(0, timeLeft / maxTime);
    const color = pct > 0.4 ? '#4caf50' : pct > 0.2 ? '#ff9800' : '#f44336';

    ctx.save();
    // Track
    ctx.strokeStyle = 'rgba(255,255,255,0.2)';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.arc(cx, y + 22, 18, -Math.PI / 2, Math.PI * 1.5);
    ctx.stroke();
    // Fill
    ctx.strokeStyle = color;
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.arc(cx, y + 22, 18, -Math.PI / 2, -Math.PI / 2 + pct * Math.PI * 2);
    ctx.stroke();
    // Number
    ctx.font = 'bold 13px monospace';
    ctx.fillStyle = color;
    ctx.textAlign = 'center';
    ctx.fillText(Math.ceil(timeLeft), cx, y + 27);
    ctx.restore();
  }

  _drawWind(ctx, x, y, wind) {
    const absWind = Math.abs(wind);
    const dir = wind >= 0 ? '→' : '←';
    ctx.font = '12px sans-serif';
    ctx.fillStyle = '#aaa';
    ctx.textAlign = 'left';
    ctx.fillText(`Wind: ${dir} ${absWind.toFixed(1)}`, x, y + 12);
  }

  _drawBottomPanel(ctx, game) {
    const W = this.W;
    const H = this.H;
    const panelY = H - PANEL_H;

    // Background
    ctx.fillStyle = 'rgba(0,0,0,0.72)';
    ctx.fillRect(0, panelY, W, PANEL_H);
    ctx.strokeStyle = 'rgba(255,255,255,0.1)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, panelY);
    ctx.lineTo(W, panelY);
    ctx.stroke();

    const ammo = game.myAmmo || {};
    const selected = game.selectedWeapon;
    const isMyTurn = game.isMyActiveTurn();

    // Weapon slots
    const slotW = 110;
    const startX = 10;
    WEAPON_ORDER.forEach((wid, i) => {
      const w = WEAPONS[wid];
      const sx = startX + i * slotW;
      const sy = panelY + 6;
      const sw = slotW - 8;
      const sh = PANEL_H - 12;
      const isSel = selected === wid;
      const qty = ammo[wid] !== undefined ? ammo[wid] : '?';
      const hasAmmo = qty === 999 || qty > 0;

      // Slot bg
      ctx.fillStyle = isSel
        ? 'rgba(255,215,0,0.25)'
        : hasAmmo && isMyTurn ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.3)';
      roundRect(ctx, sx, sy, sw, sh, 6);
      ctx.fill();

      if (isSel) {
        ctx.strokeStyle = '#ffd700';
        ctx.lineWidth = 2;
        roundRect(ctx, sx, sy, sw, sh, 6);
        ctx.stroke();
      }

      // Icon
      ctx.font = '22px serif';
      ctx.textAlign = 'center';
      ctx.globalAlpha = hasAmmo ? 1 : 0.35;
      ctx.fillText(w.icon, sx + sw / 2, sy + 30);
      ctx.globalAlpha = 1;

      // Name
      ctx.font = isSel ? 'bold 9px sans-serif' : '9px sans-serif';
      ctx.fillStyle = isSel ? '#ffd700' : hasAmmo ? '#ccc' : '#555';
      ctx.fillText(w.name, sx + sw / 2, sy + 46);

      // Ammo
      ctx.font = 'bold 10px monospace';
      ctx.fillStyle = qty === 999 ? '#666' : qty > 0 ? '#aaa' : '#f44';
      ctx.fillText(qty === 999 ? '∞' : `×${qty}`, sx + sw / 2, sy + 58);

      // Key hint
      ctx.font = '9px sans-serif';
      ctx.fillStyle = '#444';
      ctx.fillText(`[${i + 1}]`, sx + sw / 2, sy + 70);
    });

    // Right side: power + instructions
    const infoX = startX + WEAPON_ORDER.length * slotW + 20;
    const infoY = panelY + 10;

    if (isMyTurn) {
      const { angle, power } = game.currentAim;
      const deg = Math.round((angle * 180 / Math.PI + 360) % 360);
      ctx.font = '11px monospace';
      ctx.fillStyle = '#aaa';
      ctx.textAlign = 'left';
      ctx.fillText(`Angle:  ${deg}°`, infoX, infoY + 16);
      ctx.fillText(`Power:  ${Math.round(power)}%`, infoX, infoY + 32);

      // Power bar
      ctx.fillStyle = 'rgba(255,255,255,0.1)';
      roundRect(ctx, infoX, infoY + 38, 100, 10, 4);
      ctx.fill();
      ctx.fillStyle = power > 80 ? '#f44336' : power > 50 ? '#ff9800' : '#4caf50';
      roundRect(ctx, infoX, infoY + 38, power, 10, 4);
      ctx.fill();

      ctx.font = '10px sans-serif';
      ctx.fillStyle = '#666';
      ctx.fillText('A/D: move   Mouse: aim   Click: fire   E: skip', infoX, infoY + 62);

      // Movement left
      if (game.movementLeft > 0) {
        ctx.fillStyle = '#79c0ff';
        ctx.fillText(`Movement: ${Math.round(game.movementLeft)}px left`, infoX, infoY + 76);
      }
    } else {
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'left';
      if (game.currentTurn === game.myPlayerId && game.phase === 'fired') {
        ctx.fillStyle = '#ffd700';
        ctx.fillText('Shot in flight...', infoX, infoY + 30);
      } else if (game.currentTurn === game.myPlayerId && game.phase === 'laser') {
        ctx.fillStyle = '#f44336';
        ctx.fillText('🔴 Laser active — guide with mouse!', infoX, infoY + 30);
      } else {
        ctx.fillStyle = '#8b949e';
        ctx.fillText("Opponent's turn...", infoX, infoY + 30);
      }
    }
  }

  _drawAimIndicator(ctx, game) {
    const kitten = game.getMyKitten();
    if (!kitten) return;

    const { angle, power } = game.currentAim;
    const weapon = WEAPONS[game.selectedWeapon];

    // Melee: show range circle instead
    if (weapon && weapon.type === 'melee') {
      ctx.save();
      ctx.strokeStyle = 'rgba(255,100,100,0.5)';
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 4]);
      ctx.beginPath();
      ctx.arc(kitten.x, kitten.y - 20, weapon.range, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.font = '12px sans-serif';
      ctx.fillStyle = '#ff6b6b';
      ctx.textAlign = 'center';
      ctx.fillText('SLAP RANGE', kitten.x, kitten.y - 20 - weapon.range - 6);
      ctx.restore();
      return;
    }

    // Laser: just show crosshair on mouse
    if (weapon && weapon.type === 'laser') {
      const mx = game.input.mouse.x, my = game.input.mouse.y;
      ctx.save();
      ctx.strokeStyle = 'rgba(255,60,60,0.8)';
      ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(mx-10,my); ctx.lineTo(mx+10,my); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(mx,my-10); ctx.lineTo(mx,my+10); ctx.stroke();
      ctx.beginPath(); ctx.arc(mx,my,6,0,Math.PI*2); ctx.stroke();
      ctx.fillStyle='rgba(255,60,60,0.3)';
      ctx.fill();
      ctx.restore();
      return;
    }

    const len = 20 + power * 0.6;
    const ex = kitten.x + Math.cos(angle) * len;
    const ey = (kitten.y - 20) + Math.sin(angle) * len;

    ctx.save();
    // Arrow line
    ctx.strokeStyle = 'rgba(255,215,0,0.8)';
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 3]);
    ctx.beginPath();
    ctx.moveTo(kitten.x, kitten.y - 20);
    ctx.lineTo(ex, ey);
    ctx.stroke();
    ctx.setLineDash([]);

    // Arrowhead
    const hw = 8;
    ctx.fillStyle = '#ffd700';
    ctx.beginPath();
    ctx.moveTo(ex, ey);
    ctx.lineTo(ex - Math.cos(angle - 0.4) * hw, ey - Math.sin(angle - 0.4) * hw);
    ctx.lineTo(ex - Math.cos(angle + 0.4) * hw, ey - Math.sin(angle + 0.4) * hw);
    ctx.closePath();
    ctx.fill();

    // Trajectory dots (skip for scatter — too chaotic to preview meaningfully)
    if (weapon && weapon.type !== 'scatter') {
      this._drawTrajectory(ctx, kitten, angle, power, game.wind, game.terrain, game.selectedWeapon);
    }

    ctx.restore();
  }

  _drawTrajectory(ctx, kitten, angle, power, wind, terrain, weaponId) {
    if (!terrain) return;
    const weapon  = WEAPONS[weaponId] || WEAPONS['yarn'];
    const spd     = power * 7.5 * (weapon.speed   || 1);
    const gravity = weapon.gravity || GRAVITY_BASE;
    let vx = Math.cos(angle) * spd;
    let vy = Math.sin(angle) * spd;
    let x = kitten.x, y = kitten.y - 20;
    const DT = 0.016;

    ctx.fillStyle = 'rgba(255,215,0,0.32)';
    for (let i = 0; i < 90; i++) {
      vx += wind * 10 * DT;
      vy += gravity * DT;
      x  += vx * DT;
      y  += vy * DT;
      if (x < 0 || x >= terrain.width || y > terrain.getHeightAt(x) || y > WATER_Y) break;
      if (i % 4 === 0) {
        ctx.beginPath();
        ctx.arc(x, y, 2, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  _drawStatusLabels(ctx, game) {
    if (game.statusMessage) {
      ctx.save();
      ctx.font = 'bold 20px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillStyle = '#ffd700';
      ctx.strokeStyle = '#000';
      ctx.lineWidth = 4;
      ctx.strokeText(game.statusMessage, this.W / 2, this.H / 2 - 60);
      ctx.fillText(game.statusMessage, this.W / 2, this.H / 2 - 60);
      ctx.restore();
    }

    if (game.confused) {
      ctx.save();
      ctx.font = 'bold 13px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillStyle = '#ff6b6b';
      ctx.fillText('😵 CONFUSED! Controls are reversed!', this.W / 2, 72);
      ctx.restore();
    }
  }

  drawBackground(ctx, W, H) {
    // Sky gradient
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, '#1a3a5c');
    sky.addColorStop(0.5, '#2d6a9f');
    sky.addColorStop(0.8, '#4a90c4');
    sky.addColorStop(1, '#5ba8d4');
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, W, H);

    // Stars (top portion)
    ctx.fillStyle = 'rgba(255,255,255,0.6)';
    const stars = [
      [80,30],[200,15],[350,40],[500,20],[650,35],[780,18],[920,42],[1050,25],[1150,38],
      [120,55],[280,65],[440,50],[600,58],[750,62],[900,52],[1080,60]
    ];
    for (const [sx,sy] of stars) {
      ctx.beginPath();
      ctx.arc(sx, sy, 1, 0, Math.PI * 2);
      ctx.fill();
    }

    // Moon
    ctx.fillStyle = '#fffde7';
    ctx.beginPath();
    ctx.arc(1100, 60, 30, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#1a3a5c';
    ctx.beginPath();
    ctx.arc(1112, 55, 28, 0, Math.PI * 2);
    ctx.fill();

    // Clouds
    this._drawCloud(ctx, 180, 130, 0.8);
    this._drawCloud(ctx, 520, 100, 1.1);
    this._drawCloud(ctx, 850, 145, 0.7);
  }

  _drawCloud(ctx, x, y, scale) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(scale, scale);
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    const blobs = [[0,0,28],[30,0,22],[-25,5,20],[52,8,18],[-5,8,18],[25,10,16]];
    for (const [bx,by,r] of blobs) {
      ctx.beginPath();
      ctx.arc(bx, by, r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  drawWater(ctx, W) {
    const y = WATER_Y;
    const H = ctx.canvas.height;
    const grad = ctx.createLinearGradient(0, y, 0, H);
    grad.addColorStop(0, '#1a6699');
    grad.addColorStop(1, '#0d3352');
    ctx.fillStyle = grad;
    ctx.fillRect(0, y, W, H - y);

    // Shimmer lines
    const t = Date.now() / 1000;
    ctx.fillStyle = 'rgba(255,255,255,0.07)';
    for (let wx = 0; wx < W; wx += 70) {
      const shift = ((t * 25 + wx * 0.5) % 70);
      ctx.fillRect(wx + shift - 35, y + 3, 35, 2);
    }

    // "WATER" label
    ctx.font = '11px sans-serif';
    ctx.fillStyle = 'rgba(255,255,255,0.25)';
    ctx.textAlign = 'center';
    ctx.fillText('~ water ~', W / 2, y + 16);
  }
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}
