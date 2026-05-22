const express = require('express');
const { WebSocketServer } = require('ws');
const http = require('http');
const path = require('path');
const os = require('os');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

app.use(express.static(path.join(__dirname, 'public')));

const DEFAULT_HEALTH = 100;
const TURN_TIME = 35; // seconds

const INITIAL_AMMO = {
  yarn: 999,
  hairball: 3,
  catnip: 2,
  missile: 2,
  zoomies: 1,
  laser: 2,
  fish: 2,
  triple: 2
};

function makeAmmo() {
  return JSON.parse(JSON.stringify(INITIAL_AMMO));
}

let game = {
  state: 'waiting',
  players: [],
  currentTurn: 1,
  turnTimer: null,
  turnEndTime: 0,
  seed: 0,
  wind: 0,
  round: 0
};

function getLocalIPs() {
  const nets = os.networkInterfaces();
  const ips = [];
  for (const ifaces of Object.values(nets)) {
    for (const iface of ifaces) {
      if (iface.family === 'IPv4' && !iface.internal) {
        ips.push(iface.address);
      }
    }
  }
  return ips;
}

function send(ws, data) {
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify(data));
  }
}

function broadcast(data) {
  game.players.forEach(p => send(p.ws, data));
}

function getOpponent(playerId) {
  return game.players.find(p => p.id !== playerId);
}

function getPlayer(playerId) {
  return game.players.find(p => p.id === playerId);
}

function startGame() {
  game.state = 'playing';
  game.seed = Math.floor(Math.random() * 999999);
  game.wind = parseFloat(((Math.random() - 0.5) * 6).toFixed(2));
  game.currentTurn = 1;
  game.round = 1;

  game.players.forEach(p => {
    p.health = DEFAULT_HEALTH;
    p.ammo = makeAmmo();
    p.confused = false;
    p.wantsRematch = false;
  });

  broadcast({
    type: 'game_start',
    seed: game.seed,
    wind: game.wind,
    turn: game.currentTurn
  });

  startTurn();
}

function startTurn() {
  game.wind = parseFloat(((Math.random() - 0.5) * 6).toFixed(2));
  const now = Date.now();
  game.turnEndTime = now + TURN_TIME * 1000;

  clearTimeout(game.turnTimer);
  game.turnTimer = setTimeout(() => {
    // Time ran out — auto end turn
    broadcast({ type: 'time_up' });
    nextTurn();
  }, TURN_TIME * 1000);

  const active = getPlayer(game.currentTurn);
  const confused = active ? active.confused : false;

  const p1ammo = game.players.find(p=>p.id===1)?.ammo || {};
  const p2ammo = game.players.find(p=>p.id===2)?.ammo || {};

  broadcast({
    type: 'turn_start',
    playerId: game.currentTurn,
    timeLeft: TURN_TIME,
    wind: game.wind,
    confused: confused,
    ammoP1: p1ammo,
    ammoP2: p2ammo
  });

  // Clear confusion after this turn
  if (active) active.confused = false;
}

function nextTurn() {
  clearTimeout(game.turnTimer);
  game.currentTurn = game.currentTurn === 1 ? 2 : 1;
  game.round++;
  startTurn();
}

wss.on('connection', (ws) => {
  if (game.players.length >= 2) {
    send(ws, { type: 'full', message: 'Game is full. Try again later.' });
    ws.close();
    return;
  }

  const playerId = game.players.length + 1;
  const player = {
    ws,
    id: playerId,
    health: DEFAULT_HEALTH,
    ammo: makeAmmo(),
    confused: false,
    wantsRematch: false
  };
  game.players.push(player);

  const ips = getLocalIPs();
  send(ws, {
    type: 'welcome',
    playerId,
    localIPs: ips
  });

  if (game.players.length === 1) {
    send(ws, { type: 'waiting', message: 'Waiting for opponent...' });
  } else {
    // Both players connected
    startGame();
  }

  ws.on('message', (rawData) => {
    let msg;
    try { msg = JSON.parse(rawData.toString()); } catch { return; }

    switch (msg.type) {
      case 'move': {
        // Relay movement to opponent
        const opp = getOpponent(playerId);
        if (opp) send(opp.ws, { ...msg, from: playerId });
        break;
      }

      case 'fire': {
        if (game.currentTurn !== playerId) break;
        const p = getPlayer(playerId);
        if (!p) break;

        // Deduct ammo
        const wid = msg.weapon;
        if (p.ammo[wid] !== undefined && p.ammo[wid] > 0) {
          p.ammo[wid]--;
        } else if (p.ammo[wid] === 0) {
          break; // no ammo
        }

        // Relay to opponent
        const opp = getOpponent(playerId);
        if (opp) send(opp.ws, { ...msg, from: playerId });

        // Extend timer for animation (stop countdown during flight)
        clearTimeout(game.turnTimer);
        break;
      }

      case 'shot_complete': {
        // Active player reports what happened
        if (game.currentTurn !== playerId) break;

        const { targetId, damage, effect } = msg;

        if (targetId && damage > 0) {
          const target = getPlayer(targetId);
          if (target) {
            target.health = Math.max(0, target.health - damage);

            // Apply status effect
            if (effect === 'confused') {
              target.confused = true;
            }

            broadcast({
              type: 'health_update',
              playerId: targetId,
              health: target.health
            });

            if (target.health <= 0) {
              broadcast({
                type: 'game_over',
                winner: playerId,
                message: `Player ${playerId} wins!`
              });
              game.state = 'gameover';
              clearTimeout(game.turnTimer);
              return;
            }
          }
        }

        nextTurn();
        break;
      }

      case 'end_turn': {
        if (game.currentTurn !== playerId) break;
        nextTurn();
        break;
      }

      case 'rematch': {
        const p = getPlayer(playerId);
        if (p) p.wantsRematch = true;

        const opp = getOpponent(playerId);
        if (opp) send(opp.ws, { type: 'opponent_wants_rematch' });

        if (game.players.every(pl => pl.wantsRematch)) {
          startGame();
        }
        break;
      }

      case 'chat': {
        broadcast({ type: 'chat', from: playerId, message: String(msg.message).slice(0, 100) });
        break;
      }
    }
  });

  ws.on('close', () => {
    game.players = game.players.filter(p => p.id !== playerId);
    clearTimeout(game.turnTimer);

    if (game.state === 'playing') {
      broadcast({ type: 'opponent_left', message: 'Opponent disconnected.' });
    }

    if (game.players.length === 0) {
      game.state = 'waiting';
      game.currentTurn = 1;
      game.round = 0;
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  const ips = getLocalIPs();
  console.log('\n🐱 ============================');
  console.log('   KITTY TANKS SERVER RUNNING');
  console.log('🐱 ============================\n');
  console.log(`Player 1 (YOU):      http://localhost:${PORT}`);
  ips.forEach(ip => {
    console.log(`Player 2 (WIFE):     http://${ip}:${PORT}`);
  });
  console.log('\nShare the "Player 2" address with your wife!');
  console.log('Press Ctrl+C to stop the server.\n');
});
