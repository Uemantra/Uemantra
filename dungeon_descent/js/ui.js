'use strict';

// ===========================
// TILE RENDERER
// ===========================
function renderRoom(ctx, room) {
  const TS = C.TS;

  for (let y = 0; y < C.RH; y++) {
    for (let x = 0; x < C.RW; x++) {
      const t = room.getTile(x, y);
      const px2 = x * TS, py2 = y * TS;

      switch (t) {
        case TILE.VOID:
          ctx.fillStyle = C.COL.VOID;
          ctx.fillRect(px2, py2, TS, TS);
          break;

        case TILE.FLOOR:
        case TILE.FLOOR2:
          ctx.fillStyle = t === TILE.FLOOR2 ? C.COL.FLOOR2 : C.COL.FLOOR;
          ctx.fillRect(px2, py2, TS, TS);
          // Subtle grid lines
          ctx.fillStyle = 'rgba(0,0,0,0.18)';
          ctx.fillRect(px2, py2, TS, 1);
          ctx.fillRect(px2, py2, 1, TS);
          break;

        case TILE.WALL:
          // Wall face
          ctx.fillStyle = C.COL.WALL_FACE;
          ctx.fillRect(px2, py2, TS, TS);
          // Brick pattern
          const brickOffset = (y % 2 === 0) ? 0 : TS / 2;
          ctx.fillStyle = C.COL.WALL;
          ctx.fillRect(px2, py2, TS, TS);
          ctx.fillStyle = 'rgba(0,0,0,0.3)';
          ctx.fillRect(px2 + brickOffset,   py2 + 2, TS/2 - 1, TS/2 - 3);
          ctx.fillRect(px2 + brickOffset + TS/2, py2 + TS/2 + 1, TS/2 - 1, TS/2 - 3);
          // Bottom edge shadow
          ctx.fillStyle = 'rgba(0,0,0,0.4)';
          ctx.fillRect(px2, py2 + TS - 2, TS, 2);
          break;

        case TILE.WALL_TOP:
          ctx.fillStyle = C.COL.WALL_TOP;
          ctx.fillRect(px2, py2, TS, TS);
          ctx.fillStyle = C.COL.WALL_LIT;
          ctx.fillRect(px2, py2, TS, 3);
          ctx.fillStyle = 'rgba(0,0,0,0.25)';
          ctx.fillRect(px2, py2 + TS - 3, TS, 3);
          break;

        case TILE.PILLAR:
          ctx.fillStyle = C.COL.FLOOR;
          ctx.fillRect(px2, py2, TS, TS);
          ctx.fillStyle = C.COL.PILLAR;
          ctx.fillRect(px2+2, py2, TS-4, TS);
          ctx.fillStyle = C.COL.PILLAR_TOP;
          ctx.fillRect(px2+1, py2, TS-2, 3);
          break;

        case TILE.DOOR_N: case TILE.DOOR_S:
          ctx.fillStyle = C.COL.WALL;
          ctx.fillRect(px2, py2, TS, TS);
          ctx.fillStyle = C.COL.DOOR_SHUT;
          ctx.fillRect(px2+1, py2+1, TS-2, TS-2);
          ctx.fillStyle = C.COL.DOOR_FRAME;
          ctx.fillRect(px2+2, py2+2, TS-4, TS-4);
          break;

        case TILE.DOOR_E: case TILE.DOOR_W:
          ctx.fillStyle = C.COL.WALL;
          ctx.fillRect(px2, py2, TS, TS);
          ctx.fillStyle = C.COL.DOOR_SHUT;
          ctx.fillRect(px2+1, py2+1, TS-2, TS-2);
          ctx.fillStyle = C.COL.DOOR_FRAME;
          ctx.fillRect(px2+2, py2+3, TS-4, TS-6);
          break;

        case TILE.DOOR_N_O: case TILE.DOOR_S_O:
        case TILE.DOOR_E_O: case TILE.DOOR_W_O:
          ctx.fillStyle = C.COL.DOOR_OPEN;
          ctx.fillRect(px2, py2, TS, TS);
          ctx.fillStyle = '#2a1400';
          ctx.fillRect(px2+1, py2+1, TS-2, TS-2);
          // Door frame sides
          ctx.fillStyle = C.COL.DOOR_FRAME;
          ctx.fillRect(px2, py2, 2, TS);
          ctx.fillRect(px2+TS-2, py2, 2, TS);
          break;

        case TILE.STAIRS:
          // Floor base
          ctx.fillStyle = C.COL.FLOOR;
          ctx.fillRect(px2, py2, TS, TS);
          // Three ascending steps
          ctx.fillStyle = '#304858';
          ctx.fillRect(px2+2, py2+TS-5, TS-4, 2);
          ctx.fillStyle = '#406878';
          ctx.fillRect(px2+3, py2+TS-8, TS-6, 2);
          ctx.fillStyle = '#5090b0';
          ctx.fillRect(px2+4, py2+TS-11, TS-8, 2);
          // Glow accent at top step
          ctx.fillStyle = 'rgba(128,200,255,0.55)';
          ctx.fillRect(px2+4, py2+TS-11, TS-8, 1);
          // Up-arrow hint dot
          ctx.fillStyle = 'rgba(128,200,255,0.4)';
          ctx.fillRect(px2+6, py2+3, 4, 3);
          break;

        case TILE.PIT:
          // Dark void centre
          ctx.fillStyle = '#06040e';
          ctx.fillRect(px2, py2, TS, TS);
          // Crumbling edge
          ctx.fillStyle = '#2e1a0a';
          ctx.fillRect(px2,        py2,        TS, 2);
          ctx.fillRect(px2,        py2+TS-2,   TS, 2);
          ctx.fillRect(px2,        py2,        2,  TS);
          ctx.fillRect(px2+TS-2,   py2,        2,  TS);
          // Inner shadow
          ctx.fillStyle = 'rgba(0,0,0,0.55)';
          ctx.fillRect(px2+2, py2+2, TS-4, TS-4);
          break;
      }
    }
  }
}

// ===========================
// HUD
// ===========================
function renderHUD(ctx, player, dungeon, floor, roomNum, totalRooms) {
  // === HP Bar ===
  const hpW = 60, hpH = 6;
  const hpX = 4, hpY = 4;
  drawBar(ctx, hpX, hpY, hpW, hpH, player.hp, player.maxHp, C.COL.HP_FG, C.COL.HP_BG);
  // HP border
  ctx.strokeStyle = 'rgba(255,255,255,0.15)';
  ctx.lineWidth = 0.5;
  ctx.strokeRect(hpX, hpY, hpW, hpH);
  drawText(ctx, `♥ ${player.hp}/${player.maxHp}`, hpX+1, hpY+8, 5, C.COL.UI_TEXT);

  // === XP bar ===
  const xpW = 60, xpH = 3;
  drawBar(ctx, hpX, hpY+16, xpW, xpH, player.xp, player.xpNext, C.COL.XP_FG, C.COL.XP_BG);
  drawText(ctx, `LV ${player.level}`, hpX+1, hpY+20, 5, C.COL.UI_DIM);

  // === Coins ===
  ctx.fillStyle = C.COL.COIN;
  ctx.beginPath(); ctx.arc(hpX+3, hpY+30, 3, 0, Math.PI*2); ctx.fill();
  drawText(ctx, `${player.coins}`, hpX+8, hpY+27, 6, C.COL.UI_GOLD);

  // === ATK/DEF/SPD stats ===
  drawText(ctx, `ATK:${player.atk} DEF:${player.def}`, hpX+1, hpY+37, 4, C.COL.UI_DIM);

  // === Cooldown indicators ===
  const cdX = 4, cdY = C.VH - 14;
  // Sword cooldown
  const sc = player.swordCooldown / C.P_SWORD_COOLDOWN;
  drawBar(ctx, cdX, cdY, 18, 3, 1 - sc, 1, '#e0d060', '#222');
  drawText(ctx, '⚔', cdX, cdY-6, 5, sc > 0 ? '#808060' : '#e0d060');
  // Boomerang cooldown
  const pc = player.shootCooldown / C.P_SHOOT_COOLDOWN;
  drawBar(ctx, cdX+22, cdY, 18, 3, 1 - pc, 1, '#e8c850', '#222');
  drawText(ctx, '↩', cdX+22, cdY-6, 5, pc > 0 ? '#806830' : '#e8c850');
  // Block indicator (lit when actively blocking)
  const blockActive = player.blocking;
  drawBar(ctx, cdX+44, cdY, 18, 3, blockActive ? 1 : 0, 1, '#40c0e0', '#222');
  drawText(ctx, '🛡', cdX+44, cdY-6, 5, blockActive ? '#40c0e0' : '#205060');

  // === Floor / room info ===
  drawText(ctx, `Floor ${floor}/${C.MAX_FLOORS}`, C.VW - 4, 4, 5, C.COL.UI_DIM, 'right');
  drawText(ctx, `${roomNum}/${totalRooms} rms`, C.VW - 4, 11, 4, C.COL.UI_DIM, 'right');

  // === Upgrades (small icons top right area) ===
  let uIdx = 0;
  for (const [id, lvl] of player.upgrades) {
    const def = Upgrades.getDef(id);
    if (!def) continue;
    const ux = C.VW - 4 - (uIdx % 8) * 9;
    const uy = 22 + Math.floor(uIdx / 8) * 9;
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(ux-7, uy-1, 8, 8);
    ctx.fillStyle = def.color;
    ctx.font = '5px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(def.icon, ux-3, uy+3);
    if (lvl > 1) {
      drawText(ctx, String(lvl), ux-1, uy+3, 4, '#ffffff');
    }
    uIdx++;
  }

  // === Minimap ===
  renderMinimap(ctx, dungeon, floor, C.VW - 4, C.VH - 4);
}

function renderMinimap(ctx, dungeon, floor, rx, ry) {
  const CELL = 7, GAP = 1, PAD = 3;
  const allRooms = Object.values(dungeon.rooms);
  if (!allRooms.length) return;

  const minGX = Math.min(...allRooms.map(r => r.gx));
  const minGY = Math.min(...allRooms.map(r => r.gy));
  const maxGX = Math.max(...allRooms.map(r => r.gx));
  const maxGY = Math.max(...allRooms.map(r => r.gy));

  const cols = maxGX - minGX + 1;
  const rows = maxGY - minGY + 1;
  const mapW = cols * (CELL + GAP) - GAP + PAD * 2;
  const mapH = rows * (CELL + GAP) - GAP + PAD * 2 + 8;
  const mapX = rx - mapW, mapY = ry - mapH;

  // Background + border
  ctx.fillStyle = 'rgba(4,2,12,0.82)';
  ctx.fillRect(mapX, mapY, mapW, mapH);
  ctx.strokeStyle = C.COL.UI_BORDER;
  ctx.lineWidth = 0.5;
  ctx.strokeRect(mapX, mapY, mapW, mapH);

  // Floor label
  drawText(ctx, `B${floor}/${C.MAX_FLOORS}`, mapX + PAD, mapY + 2, 4, C.COL.UI_DIM);

  const contentY = mapY + PAD + 8;
  const cellX = (r) => mapX + PAD + (r.gx - minGX) * (CELL + GAP);
  const cellY = (r) => contentY + (r.gy - minGY) * (CELL + GAP);

  // Pass 1: faint outlines for unvisited rooms adjacent to visited ones
  for (const room of allRooms) {
    if (room.visited) continue;
    const hasNeighbor = Object.values(room.connections).some(n => n && n.visited);
    if (!hasNeighbor) continue;
    ctx.strokeStyle = 'rgba(80,60,110,0.45)';
    ctx.lineWidth = 0.5;
    ctx.strokeRect(cellX(room), cellY(room), CELL, CELL);
  }

  // Pass 2: visited rooms
  for (const room of allRooms) {
    if (!room.visited) continue;
    const cx = cellX(room), cy = cellY(room);
    const isCurrent = room === dungeon.currentRoom;

    // Base fill
    let col;
    if      (isCurrent)                          col = '#3a5060';
    else if (room.type === RTYPE.BOSS && !room.cleared) col = '#4a1020';
    else if (room.type === RTYPE.BOSS)           col = '#2e1530';
    else if (room.type === RTYPE.TREASURE && !room.cleared) col = '#38400a';
    else if (room.type === RTYPE.TREASURE)       col = '#252c08';
    else if (room.type === RTYPE.SHOP)           col = '#0e2e20';
    else if (room.type === RTYPE.START)          col = '#182535';
    else if (!room.cleared)                      col = '#28263e';
    else                                         col = '#181a24';

    ctx.fillStyle = col;
    ctx.fillRect(cx, cy, CELL, CELL);

    // Type corner dot (top-right, 2×2)
    if (room.type === RTYPE.BOSS) {
      ctx.fillStyle = room.cleared ? '#804080' : '#ff2840';
      ctx.fillRect(cx + CELL - 2, cy, 2, 2);
    } else if (room.type === RTYPE.TREASURE) {
      ctx.fillStyle = '#f0c030';
      ctx.fillRect(cx + CELL - 2, cy, 2, 2);
    } else if (room.type === RTYPE.SHOP) {
      ctx.fillStyle = '#40e090';
      ctx.fillRect(cx + CELL - 2, cy, 2, 2);
    } else if (room.type === RTYPE.START) {
      ctx.fillStyle = '#80c0ff';
      ctx.fillRect(cx + CELL - 2, cy, 2, 2);
    }

    // Stairs dot (bottom-left, 2×2)
    if (room.hasStairs) {
      ctx.fillStyle = '#80c0ff';
      ctx.fillRect(cx, cy + CELL - 2, 2, 2);
    }

    // Current room: white border + yellow player dot
    if (isCurrent) {
      ctx.strokeStyle = 'rgba(255,255,255,0.85)';
      ctx.lineWidth = 0.5;
      ctx.strokeRect(cx, cy, CELL, CELL);
      ctx.fillStyle = '#ffff50';
      ctx.fillRect(cx + 2, cy + 2, 3, 3);
    }

    // Connection corridors to visited neighbours
    ctx.fillStyle = 'rgba(110,90,140,0.75)';
    if (room.connections.e && room.connections.e.visited)
      ctx.fillRect(cx + CELL, cy + 2, GAP, CELL - 4);
    if (room.connections.s && room.connections.s.visited)
      ctx.fillRect(cx + 2, cy + CELL, CELL - 4, GAP);
  }
}

// ===========================
// UPGRADE SELECTION SCREEN
// ===========================
function renderUpgradeScreen(ctx, choices, hoverIdx, anim, inputReady) {
  // Dim background
  ctx.fillStyle = 'rgba(5,3,15,0.88)';
  ctx.fillRect(0, 0, C.VW, C.VH);

  // Title
  drawTextShadow(ctx, '✦ CHOOSE YOUR PATH ✦', C.VW/2, 30, 10, C.COL.UI_GOLD, '#000');

  const cardW = 80, cardH = 110, gap = 10;
  const totalW = choices.length * cardW + (choices.length - 1) * gap;
  const startX = (C.VW - totalW) / 2;

  for (let i = 0; i < choices.length; i++) {
    const u = choices[i];
    const cx = startX + i * (cardW + gap);
    const cy = 50;
    const hovered = i === hoverIdx;
    const cardY = cy + (hovered ? -4 : 0);

    // Card shadow
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(cx+2, cardY+2, cardW, cardH);

    // Card background
    ctx.fillStyle = hovered ? C.COL.UI_BG2 : C.COL.UI_BG;
    ctx.fillRect(cx, cardY, cardW, cardH);

    // Card border
    ctx.strokeStyle = hovered ? u.color : C.COL.UI_BORDER;
    ctx.lineWidth = hovered ? 1.5 : 0.5;
    ctx.strokeRect(cx, cardY, cardW, cardH);

    // Color stripe at top
    ctx.fillStyle = u.color;
    ctx.fillRect(cx, cardY, cardW, 4);
    ctx.fillStyle = 'rgba(255,255,255,0.2)';
    ctx.fillRect(cx, cardY, cardW, 1);

    // Category
    const catColors = { offense: '#ff8040', defense: '#60a0ff', utility: '#60e080' };
    drawText(ctx, u.category.toUpperCase(), cx+4, cardY+7, 4, catColors[u.category] || '#aaa');

    // Icon
    ctx.save();
    ctx.font = `18px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(u.icon, cx + cardW/2, cardY + 30);
    ctx.restore();

    // Name
    drawTextShadow(ctx, u.name, cx + cardW/2, cardY + 47, 6, '#ffffff', '#000');

    // Level display
    const playerLvl = 0; // passed in separately, show current+1
    const newLvl = playerLvl + 1;
    if (u.maxLevel > 1) {
      drawText(ctx, `LEVEL ${newLvl}`, cx+4, cardY+56, 4, C.COL.UI_GOLD);
    }

    // Description (word-wrapped)
    const desc = u.desc(newLvl);
    const words = desc.split(' ');
    let line = '', lineY = cardY + 65;
    ctx.font = `4px 'Courier New'`;
    ctx.fillStyle = C.COL.UI_DIM;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    for (const w of words) {
      const test = line ? line + ' ' + w : w;
      if (ctx.measureText(test).width > cardW - 8) {
        ctx.fillText(line, cx+4, lineY);
        line = w; lineY += 7;
      } else {
        line = test;
      }
    }
    if (line) ctx.fillText(line, cx+4, lineY);

    // Hover indicator
    if (hovered) {
      ctx.fillStyle = 'rgba(255,255,255,0.05)';
      ctx.fillRect(cx, cardY, cardW, cardH);
      // Animated border glow
      ctx.globalAlpha = 0.5 + Math.sin(anim * 6) * 0.3;
      ctx.strokeStyle = u.color;
      ctx.lineWidth = 2;
      ctx.strokeRect(cx-1, cardY-1, cardW+2, cardH+2);
      ctx.globalAlpha = 1;
    }

    // Select hint — only shown once input is unlocked
    if (hovered && inputReady) {
      drawTextShadow(ctx, '[CLICK or ENTER]', cx + cardW/2, cardY + cardH - 6, 4, '#ffffff', '#000');
    }
  }

  // Key hints
  if (inputReady) {
    drawText(ctx, '← → to browse   Click or Enter to select', C.VW/2, C.VH - 10, 4, C.COL.UI_DIM, 'center');
  } else {
    drawText(ctx, '— take a moment to choose —', C.VW/2, C.VH - 10, 4, C.COL.UI_DIM, 'center');
  }
}

// ===========================
// GAME OVER SCREEN
// ===========================
function renderGameOver(ctx, player, floor, anim) {
  ctx.fillStyle = 'rgba(5,0,10,0.95)';
  ctx.fillRect(0, 0, C.VW, C.VH);

  const pulse = Math.sin(anim * 3) * 3;
  drawTextShadow(ctx, 'YOU DIED', C.VW/2, 70 + pulse, 18, C.COL.UI_RED, '#000');
  drawText(ctx, '— — — — —', C.VW/2, 92, 7, C.COL.UI_BORDER, 'center');

  drawTextShadow(ctx, `Floor ${floor}`, C.VW/2, 104, 8, C.COL.UI_DIM, '#000');
  drawTextShadow(ctx, `Level ${player.level}`, C.VW/2, 114, 7, C.COL.UI_DIM, '#000');
  drawTextShadow(ctx, `Kills: ${player.kills}`, C.VW/2, 124, 7, C.COL.UI_DIM, '#000');
  drawTextShadow(ctx, `Rooms: ${player.roomsCleared}`, C.VW/2, 134, 7, C.COL.UI_DIM, '#000');

  // Upgrades collected
  const ids = Array.from(player.upgrades.keys());
  if (ids.length > 0) {
    drawText(ctx, 'UPGRADES COLLECTED:', C.VW/2, 148, 5, C.COL.UI_BORDER, 'center');
    for (let i = 0; i < Math.min(ids.length, 6); i++) {
      const def = Upgrades.getDef(ids[i]);
      if (def) drawText(ctx, `${def.icon} ${def.name}`, C.VW/2, 157 + i*8, 5, def.color, 'center');
    }
  }

  const btnY = C.VH - 30;
  const flash = Math.floor(anim * 2) % 2 === 0;
  if (flash) {
    drawTextShadow(ctx, '[ PRESS ENTER or CLICK to restart ]', C.VW/2, btnY, 5, '#ffffff', '#000');
  }
}

// ===========================
// VICTORY SCREEN
// ===========================
function renderVictory(ctx, player, floor, anim) {
  // Starfield
  ctx.fillStyle = 'rgba(5,3,20,0.85)';
  ctx.fillRect(0, 0, C.VW, C.VH);

  // Floating stars
  for (let i = 0; i < 30; i++) {
    const sx = (i * 37 + anim * 20) % C.VW;
    const sy = (i * 59 + anim * 10) % C.VH;
    const s = 1 + (i % 3);
    ctx.fillStyle = `rgba(255,200,100,${0.3 + (i%3)*0.2})`;
    ctx.fillRect(sx, sy, s, s);
  }

  const pulse = Math.sin(anim * 4) * 2;
  drawTextShadow(ctx, '✦ VICTORY! ✦', C.VW/2, 55 + pulse, 14, C.COL.UI_GOLD, '#000');
  drawText(ctx, `All ${C.MAX_FLOORS} floors cleared!`, C.VW/2, 76, 5, C.COL.UI_TEXT, 'center');
  drawText(ctx, '— — — — —', C.VW/2, 86, 7, C.COL.UI_BORDER, 'center');

  drawTextShadow(ctx, `Floor ${floor}`, C.VW/2, 98, 7, C.COL.UI_DIM, '#000');
  drawTextShadow(ctx, `Level ${player.level}  |  Kills: ${player.kills}`, C.VW/2, 108, 6, C.COL.UI_DIM, '#000');
  drawTextShadow(ctx, `Upgrades: ${player.upgrades.size}`, C.VW/2, 118, 6, C.COL.UI_GOLD, '#000');

  const flash = Math.floor(anim * 2) % 2 === 0;
  if (flash) {
    drawTextShadow(ctx, '[ PRESS ENTER to play again ]', C.VW/2, C.VH - 20, 5, '#ffffff', '#000');
  }
}

// ===========================
// MAIN MENU
// ===========================
function renderMainMenu(ctx, anim) {
  // Dark background with animated gradient
  ctx.fillStyle = C.COL.BG;
  ctx.fillRect(0, 0, C.VW, C.VH);

  // Animated pixel particles in background
  for (let i = 0; i < 20; i++) {
    const x = ((i * 47 + anim * 15) % C.VW);
    const y = ((i * 31 + anim * 8)  % C.VH);
    ctx.fillStyle = `rgba(100,60,200,${0.2 + (i%4)*0.1})`;
    ctx.fillRect(x, y, 2, 2);
  }

  // Title
  const pulse = Math.sin(anim * 2.5) * 2;
  ctx.fillStyle = 'rgba(50,20,80,0.7)';
  ctx.fillRect(30, 25 + pulse, C.VW - 60, 38);

  drawTextShadow(ctx, 'DUNGEON', C.VW/2, 34 + pulse, 18, C.COL.UI_GOLD, '#000');
  drawTextShadow(ctx, 'DESCENT', C.VW/2, 52 + pulse, 18, C.COL.UI_PURPLE, '#000');

  // Subtitle
  drawText(ctx, 'A Zelda-Roguelike Adventure', C.VW/2, 72, 5, C.COL.UI_DIM, 'center');

  // Show a player character
  const t = anim * 2;
  ctx.save();
  ctx.translate(C.VW/2, 105);
  drawPlayer(ctx, 0, 0, 'down', t, false, 0, 0, 0, new Set());
  ctx.restore();

  // Feature bullets
  const features = [
    '⚔  Melee & ranged combat',
    '♦  30+ unique upgrades',
    '🗺  Procedural dungeons',
    '👹  6 enemy types + boss',
  ];
  for (let i = 0; i < features.length; i++) {
    drawText(ctx, features[i], C.VW/2, 130 + i * 10, 5, C.COL.UI_TEXT, 'center');
  }

  // Controls
  drawText(ctx, 'WASD: Move   Click/Z: Sword   X: Shoot   Space: Dodge', C.VW/2, 182, 4, C.COL.UI_DIM, 'center');
  drawText(ctx, 'M: Mute   P/Esc: Pause', C.VW/2, 190, 4, C.COL.UI_DIM, 'center');

  // Start prompt
  const flash = Math.floor(anim * 2) % 2 === 0;
  if (flash) {
    drawTextShadow(ctx, '[ PRESS ENTER or CLICK to start ]', C.VW/2, 210, 6, '#ffffff', '#000');
  }
}

// ===========================
// PAUSE SCREEN
// ===========================
function renderPause(ctx, player, anim) {
  ctx.fillStyle = 'rgba(5,3,15,0.82)';
  ctx.fillRect(0, 0, C.VW, C.VH);
  drawTextShadow(ctx, 'PAUSED', C.VW/2, C.VH/2 - 20, 14, C.COL.UI_TEXT, '#000');
  drawText(ctx, 'P or Esc to resume', C.VW/2, C.VH/2 + 5, 6, C.COL.UI_DIM, 'center');
  drawText(ctx, 'M to toggle sound', C.VW/2, C.VH/2 + 15, 5, C.COL.UI_DIM, 'center');
}

// ===========================
// BOSS HEALTH BAR
// ===========================
function renderBossBar(ctx, boss) {
  if (!boss || boss.dead) return;
  const bw = 160, bh = 8, bx = (C.VW - bw) / 2, by = C.VH - 18;
  ctx.fillStyle = 'rgba(0,0,0,0.6)';
  ctx.fillRect(bx-2, by-2, bw+4, bh+4);
  drawBar(ctx, bx, by, bw, bh, boss.hp, boss.maxHp, C.COL.BOSS, C.COL.HP_BG);
  ctx.strokeStyle = C.COL.UI_BORDER;
  ctx.lineWidth = 0.5;
  ctx.strokeRect(bx, by, bw, bh);
  drawTextShadow(ctx, 'THE LICH', C.VW/2, by - 6, 5, C.COL.UI_PURPLE, '#000');
}

// ===========================
// ROOM CLEAR FLASH
// ===========================
function renderClearFlash(ctx, t) {
  // t goes 0 → 1
  ctx.globalAlpha = (1 - t) * 0.4;
  ctx.fillStyle = '#80e0a0';
  ctx.fillRect(0, 0, C.VW, C.VH);
  ctx.globalAlpha = 1;
}

// Camera shake
const CameraShake = {
  x: 0, y: 0,
  power: 0, timer: 0,

  shake(power, duration) {
    this.power = Math.max(this.power, power);
    this.timer = Math.max(this.timer, duration);
  },

  update(dt) {
    if (this.timer > 0) {
      this.timer -= dt;
      this.x = (Math.random() - 0.5) * this.power;
      this.y = (Math.random() - 0.5) * this.power;
      if (this.timer <= 0) { this.x = 0; this.y = 0; this.power = 0; }
    }
  },
};
