'use strict';

const TILE = {
  VOID:     0,
  FLOOR:    1,
  FLOOR2:   2,
  WALL:     3,
  WALL_TOP: 4,
  PILLAR:   5,
  DOOR_N:   10,
  DOOR_S:   11,
  DOOR_E:   12,
  DOOR_W:   13,
  DOOR_N_O: 14,
  DOOR_S_O: 15,
  DOOR_E_O: 16,
  DOOR_W_O: 17,
  STAIRS:   18,
  PIT:      19,
};

const RTYPE = {
  START:    'start',
  NORMAL:   'normal',
  TREASURE: 'treasure',
  SHOP:     'shop',
  BOSS:     'boss',
};

function isSolid(t) {
  return t === TILE.VOID || t === TILE.WALL || t === TILE.WALL_TOP ||
         t === TILE.PILLAR || t === TILE.DOOR_N || t === TILE.DOOR_S ||
         t === TILE.DOOR_E || t === TILE.DOOR_W;
}

function isDoor(t) {
  return t >= TILE.DOOR_N && t <= TILE.DOOR_W_O;
}

function isOpenDoor(t) {
  return t === TILE.DOOR_N_O || t === TILE.DOOR_S_O ||
         t === TILE.DOOR_E_O || t === TILE.DOOR_W_O;
}

function isStairs(t) { return t === TILE.STAIRS; }
function isPit(t)    { return t === TILE.PIT; }

// ------- Room -------
class Room {
  constructor(gx, gy, type) {
    this.gx = gx; this.gy = gy;
    this.type = type || RTYPE.NORMAL;
    this.cleared = false;
    this.visited = false;
    this.connections = { n: null, s: null, e: null, w: null };
    this.tiles = null;
    this.enemies = [];
    this.items = [];
    this.chest = null;
    this.chestOpened = false;
    this.hasStairs = false;
    this.shopItems = [];
    this._generate();
  }

  _generate() {
    const W = C.RW, H = C.RH;
    const tiles = [];
    for (let y = 0; y < H; y++) {
      tiles.push(new Uint8Array(W));
      for (let x = 0; x < W; x++) {
        if (x === 0 || x === W-1 || y === 0 || y === H-1) {
          tiles[y][x] = (y === 0) ? TILE.WALL_TOP : TILE.WALL;
        } else {
          tiles[y][x] = rBool(0.15) ? TILE.FLOOR2 : TILE.FLOOR;
        }
      }
    }

    // Interior obstacles (skip for start/boss)
    if (this.type === RTYPE.NORMAL || this.type === RTYPE.SHOP || this.type === RTYPE.TREASURE) {
      // Corner pillars
      const cps = [[4,4],[W-5,4],[4,H-5],[W-5,H-5]];
      for (const [px,py] of cps) {
        if (rBool(0.55)) {
          tiles[py][px]   = TILE.PILLAR;
          tiles[py-1][px] = TILE.WALL_TOP;
        }
      }
      // Random wall sections
      const sections = rInt(0, 3);
      for (let s = 0; s < sections; s++) {
        const x = rInt(3, W-4), y = rInt(3, H-4);
        const len = rInt(2, 4), horiz = rBool();
        for (let i = 0; i < len; i++) {
          const tx = horiz ? x+i : x, ty = horiz ? y : y+i;
          if (tx > 1 && tx < W-2 && ty > 1 && ty < H-2) {
            tiles[ty][tx] = TILE.WALL;
            if (ty > 1) tiles[ty-1][tx] = TILE.WALL_TOP;
          }
        }
      }
    }

    this.tiles = tiles;
  }

  setDoors(n, s, e, w) {
    const W = C.RW, H = C.RH;
    const mx = Math.floor(W/2), my = Math.floor(H/2);
    const t = this.tiles;

    const clearAround = (tx, ty) => {
      for (let dy=-1;dy<=1;dy++) for (let dx=-1;dx<=1;dx++) {
        const nx=tx+dx, ny=ty+dy;
        if (nx>0&&nx<W-1&&ny>0&&ny<H-1 && isSolid(t[ny][nx]) && !isDoor(t[ny][nx]))
          t[ny][nx] = TILE.FLOOR;
      }
    };

    if (n) { t[0][mx-1]=t[0][mx]=TILE.DOOR_N; clearAround(mx,1); }
    if (s) { t[H-1][mx-1]=t[H-1][mx]=TILE.DOOR_S; clearAround(mx,H-2); }
    if (e) {
      t[my-1][W-1]=t[my][W-1]=t[my+1][W-1]=TILE.DOOR_E;
      clearAround(W-2,my);
    }
    if (w) {
      t[my-1][0]=t[my][0]=t[my+1][0]=TILE.DOOR_W;
      clearAround(1,my);
    }
  }

  openDoors() {
    const map = {
      [TILE.DOOR_N]: TILE.DOOR_N_O, [TILE.DOOR_S]: TILE.DOOR_S_O,
      [TILE.DOOR_E]: TILE.DOOR_E_O, [TILE.DOOR_W]: TILE.DOOR_W_O,
    };
    for (let y=0;y<C.RH;y++) for (let x=0;x<C.RW;x++) {
      const m = map[this.tiles[y][x]];
      if (m !== undefined) this.tiles[y][x] = m;
    }
  }

  closeDoors() {
    const map = {
      [TILE.DOOR_N_O]: TILE.DOOR_N, [TILE.DOOR_S_O]: TILE.DOOR_S,
      [TILE.DOOR_E_O]: TILE.DOOR_E, [TILE.DOOR_W_O]: TILE.DOOR_W,
    };
    for (let y=0;y<C.RH;y++) for (let x=0;x<C.RW;x++) {
      const m = map[this.tiles[y][x]];
      if (m !== undefined) this.tiles[y][x] = m;
    }
  }

  getTile(tx, ty) {
    if (tx<0||tx>=C.RW||ty<0||ty>=C.RH) return TILE.VOID;
    return this.tiles[ty][tx];
  }

  // Returns if a world-space pixel position is walkable
  canWalk(wx, wy) {
    const tx = Math.floor(wx / C.TS), ty = Math.floor(wy / C.TS);
    return !isSolid(this.getTile(tx, ty));
  }

  // Free floor positions away from center (for enemy spawning)
  spawnPoints() {
    const pts = [];
    for (let y=2;y<C.RH-2;y++) for (let x=2;x<C.RW-2;x++) {
      if (this.tiles[y][x] === TILE.FLOOR || this.tiles[y][x] === TILE.FLOOR2) {
        const wx=x*C.TS+8, wy=y*C.TS+8;
        const cx=C.VW/2, cy=C.VH/2;
        if (dist(wx,wy,cx,cy) > 48) pts.push({x:wx,y:wy});
      }
    }
    return rShuffle(pts);
  }

  chestPos() {
    const cx = Math.floor(C.RW/2), cy = Math.floor(C.RH/2);
    return { x: cx*C.TS+4, y: cy*C.TS+2 };
  }

  placeStairs() {
    const cx = Math.floor(C.RW / 2);
    const cy = Math.floor(C.RH / 2);
    this.tiles[cy][cx] = TILE.STAIRS;
    this.hasStairs = true;
  }

  placePits(count) {
    const candidates = [];
    for (let y = 2; y < C.RH - 2; y++) {
      for (let x = 2; x < C.RW - 2; x++) {
        const t = this.tiles[y][x];
        if (t === TILE.FLOOR || t === TILE.FLOOR2) candidates.push({x, y});
      }
    }
    const chosen = rShuffle(candidates).slice(0, count);
    for (const {x, y} of chosen) this.tiles[y][x] = TILE.PIT;
  }
}

// ------- Dungeon -------
class Dungeon {
  constructor(floor) {
    this.floor = floor || 1;
    this.rooms = {};
    this.startRoom = null;
    this.bossRoom = null;
    this.currentRoom = null;
    this._generate();
  }

  key(gx,gy) { return `${gx},${gy}`; }

  _generate() {
    const DW=C.DW, DH=C.DH;
    const sx=Math.floor(DW/2), sy=Math.floor(DH/2);
    const visited = new Set();
    const roomPos = [];

    // Random walk
    visited.add(this.key(sx,sy));
    roomPos.push({x:sx,y:sy});
    const target = rInt(C.MIN_ROOMS, C.MAX_ROOMS);
    let tries = 0;
    while (roomPos.length < target && tries++ < 2000) {
      const base = rPick(roomPos);
      const dirs = rShuffle([{dx:0,dy:-1},{dx:0,dy:1},{dx:1,dy:0},{dx:-1,dy:0}]);
      for (const {dx,dy} of dirs) {
        const nx=base.x+dx, ny=base.y+dy;
        if (nx>=0&&nx<DW&&ny>=0&&ny<DH&&!visited.has(this.key(nx,ny))) {
          visited.add(this.key(nx,ny));
          roomPos.push({x:nx,y:ny});
          break;
        }
      }
    }

    // Find farthest room from start (for boss)
    let maxD=0, bossPos={x:sx,y:sy};
    for (const p of roomPos) {
      const d=Math.abs(p.x-sx)+Math.abs(p.y-sy);
      if (d>maxD) { maxD=d; bossPos=p; }
    }

    // Assign room types
    const shopRooms = new Set();
    const treasureRooms = new Set();
    for (const p of roomPos) {
      const k = this.key(p.x,p.y);
      if (k===this.key(sx,sy)||k===this.key(bossPos.x,bossPos.y)) continue;
      if (!shopRooms.size && rBool(0.35)) shopRooms.add(k);
      else if (!treasureRooms.size && rBool(0.3)) treasureRooms.add(k);
    }

    for (const p of roomPos) {
      const k = this.key(p.x,p.y);
      let type = RTYPE.NORMAL;
      if (k === this.key(sx,sy))          type = RTYPE.START;
      else if (k === this.key(bossPos.x,bossPos.y)) type = RTYPE.BOSS;
      else if (shopRooms.has(k))          type = RTYPE.SHOP;
      else if (treasureRooms.has(k))      type = RTYPE.TREASURE;

      const room = new Room(p.x, p.y, type);
      this.rooms[k] = room;
      if (type===RTYPE.START) this.startRoom = room;
      if (type===RTYPE.BOSS)  this.bossRoom  = room;
    }

    // Wire connections and doors
    for (const p of roomPos) {
      const room = this.rooms[this.key(p.x,p.y)];
      const n = this.rooms[this.key(p.x,p.y-1)] || null;
      const s = this.rooms[this.key(p.x,p.y+1)] || null;
      const e = this.rooms[this.key(p.x+1,p.y)] || null;
      const w = this.rooms[this.key(p.x-1,p.y)] || null;
      room.connections.n=n; room.connections.s=s;
      room.connections.e=e; room.connections.w=w;
      room.setDoors(!!n,!!s,!!e,!!w);
    }

    // Place pits in some normal rooms on floors 2+ (so falling takes you back down)
    if (this.floor >= 2) {
      for (const k of Object.keys(this.rooms)) {
        const room = this.rooms[k];
        if (room.type === RTYPE.NORMAL && rBool(0.45)) {
          room.placePits(rInt(1, 3));
        }
      }
    }

    // Start room pre-cleared
    this.startRoom.cleared=true;
    this.startRoom.visited=true;
    this.startRoom.openDoors();
    this.currentRoom = this.startRoom;
  }

  room(gx,gy) { return this.rooms[this.key(gx,gy)]||null; }
}
