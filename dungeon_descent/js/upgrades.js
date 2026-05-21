'use strict';

// All available upgrades
const UPGRADE_DEFS = [
  // ====== OFFENSE ======
  {
    id: 'sharp_blade', name: 'Sharp Blade', tier: 1, maxLevel: 3,
    icon: '⚔', color: '#e06030',
    desc: (lvl) => `+${lvl * 2} ATK`,
    category: 'offense',
  },
  {
    id: 'swift_strikes', name: 'Swift Strikes', tier: 1, maxLevel: 2,
    icon: '⚡', color: '#f0c030',
    desc: (lvl) => `Melee cooldown -${lvl * 20}%`,
    category: 'offense',
  },
  {
    id: 'critical_force', name: 'Critical Force', tier: 2, maxLevel: 3,
    icon: '💥', color: '#ff8040',
    desc: (lvl) => `${15 + lvl * 5}% chance for 2× damage`,
    category: 'offense',
  },
  {
    id: 'poison_touch', name: 'Poison Touch', tier: 2, maxLevel: 1,
    icon: '☠', color: '#60c040',
    desc: () => 'Melee applies 4s poison',
    category: 'offense',
  },
  {
    id: 'fire_aspect', name: 'Fire Aspect', tier: 2, maxLevel: 1,
    icon: '🔥', color: '#ff6020',
    desc: () => 'Attacks set enemies on fire',
    category: 'offense',
  },
  {
    id: 'multishot', name: 'Multiboomerang', tier: 2, maxLevel: 2,
    icon: '✦', color: '#a060ff',
    desc: (lvl) => `+${lvl} extra boomerang${lvl > 1 ? 's' : ''} thrown`,
    category: 'offense',
  },
  {
    id: 'piercing_shots', name: 'Piercing Rang', tier: 2, maxLevel: 1,
    icon: '➤', color: '#80c0ff',
    desc: () => 'Boomerang passes through enemies',
    category: 'offense',
  },
  {
    id: 'homing_bolts', name: 'Seeking Rang', tier: 3, maxLevel: 1,
    icon: '↺', color: '#c080ff',
    desc: () => 'Boomerang homes in on enemies',
    category: 'offense',
  },
  {
    id: 'giant_blade', name: 'Giant Blade', tier: 2, maxLevel: 1,
    icon: '🗡', color: '#c0c0e0',
    desc: () => 'Sword range ×1.5',
    category: 'offense',
  },
  {
    id: 'soul_rend', name: 'Soul Rend', tier: 3, maxLevel: 1,
    icon: '👻', color: '#c0a0ff',
    desc: () => 'Kills grant +1 ATK stack (max 5)',
    category: 'offense',
  },
  {
    id: 'explosive_finale', name: 'Explosive Finale', tier: 3, maxLevel: 1,
    icon: '💣', color: '#ff8020',
    desc: () => 'Kills cause a small explosion',
    category: 'offense',
  },
  {
    id: 'longer_range', name: 'Long Arm', tier: 1, maxLevel: 2,
    icon: '🏹', color: '#c8a860',
    desc: (lvl) => `Boomerang range +${lvl * 40}%`,
    category: 'offense',
  },
  {
    id: 'knockback_force', name: 'Knockback Force', tier: 2, maxLevel: 2,
    icon: '💨', color: '#e09030',
    desc: (lvl) => `Sword knockback +${lvl * 50}%`,
    category: 'offense',
  },

  // ====== DEFENSE ======
  {
    id: 'iron_body', name: 'Iron Body', tier: 1, maxLevel: 3,
    icon: '🛡', color: '#8090c0',
    desc: (lvl) => `+${lvl * 4} max HP`,
    category: 'defense',
  },
  {
    id: 'stoneskin', name: 'Stoneskin', tier: 2, maxLevel: 2,
    icon: '🪨', color: '#909080',
    desc: (lvl) => `+${lvl} DEF (reduce damage)`,
    category: 'defense',
  },
  {
    id: 'lifesteal', name: 'Lifesteal', tier: 2, maxLevel: 1,
    icon: '❤', color: '#e03060',
    desc: () => 'Heal 1 HP per kill',
    category: 'defense',
  },
  {
    id: 'vampiric', name: 'Vampiric', tier: 2, maxLevel: 1,
    icon: '🩸', color: '#c02050',
    desc: () => 'Melee hits heal 1 HP',
    category: 'defense',
  },
  {
    id: 'dodge_master', name: 'Block Mastery', tier: 2, maxLevel: 1,
    icon: '◎', color: '#40c0e0',
    desc: () => 'Blocking reduces 80% damage (up from 50%)',
    category: 'defense',
  },
  {
    id: 'shield_bash', name: 'Riposte', tier: 2, maxLevel: 1,
    icon: '🔰', color: '#60a0ff',
    desc: () => 'Blocking when hit stuns the attacker 1.5s',
    category: 'defense',
  },
  {
    id: 'thorns', name: 'Thorns', tier: 2, maxLevel: 2,
    icon: '🌵', color: '#60a040',
    desc: (lvl) => `Attackers take ${lvl} damage`,
    category: 'defense',
  },
  {
    id: 'shield_block', name: 'Shield Block', tier: 3, maxLevel: 1,
    icon: '🛡', color: '#60c0ff',
    desc: () => '20% chance to block all damage',
    category: 'defense',
  },
  {
    id: 'regeneration', name: 'Regeneration', tier: 2, maxLevel: 2,
    icon: '✚', color: '#40e080',
    desc: (lvl) => `Regen ${lvl} HP per ${5 - (lvl-1)} sec`,
    category: 'defense',
  },
  {
    id: 'last_stand', name: 'Last Stand', tier: 3, maxLevel: 1,
    icon: '⚔', color: '#ff4040',
    desc: () => '+50% ATK when HP ≤ 3',
    category: 'defense',
  },
  {
    id: 'orbit_shield', name: 'Orbit Shield', tier: 3, maxLevel: 1,
    icon: '🌀', color: '#40d0ff',
    desc: () => 'Orbiting shields block projectiles',
    category: 'defense',
  },

  // ====== UTILITY ======
  {
    id: 'fleet_foot', name: 'Fleet Foot', tier: 1, maxLevel: 3,
    icon: '👟', color: '#40e0a0',
    desc: (lvl) => `+${lvl * 12} speed`,
    category: 'utility',
  },
  {
    id: 'lucky_star', name: 'Lucky Star', tier: 1, maxLevel: 2,
    icon: '⭐', color: '#f0d040',
    desc: (lvl) => `+${lvl} LUCK (more coins & upgrades)`,
    category: 'utility',
  },
  {
    id: 'berserker_rage', name: 'Berserker Rage', tier: 3, maxLevel: 1,
    icon: '😡', color: '#ff4020',
    desc: () => '+60% ATK & SPD when HP < 30%',
    category: 'utility',
  },
  {
    id: 'shadow_cloak', name: 'Stalwart', tier: 2, maxLevel: 1,
    icon: '🌑', color: '#6060a0',
    desc: () => 'Blocking no longer slows movement',
    category: 'utility',
  },
  {
    id: 'momentum', name: 'Momentum', tier: 2, maxLevel: 1,
    icon: '🌊', color: '#40a0ff',
    desc: () => 'Speed increases while moving',
    category: 'utility',
  },
  {
    id: 'coin_magnet', name: 'Coin Magnet', tier: 1, maxLevel: 1,
    icon: '🧲', color: '#f0c030',
    desc: () => 'Auto-collect nearby coins',
    category: 'utility',
  },
];

const UPGRADE_MAP = {};
for (const u of UPGRADE_DEFS) UPGRADE_MAP[u.id] = u;

const Upgrades = {
  // Build a pool of 3 random upgrades to offer
  buildPool(player, count) {
    count = count || 3;
    // Filter: not at max level
    const available = UPGRADE_DEFS.filter(u => {
      const lvl = player.upgradeLevel(u.id);
      return lvl < u.maxLevel;
    });

    if (!available.length) return [];

    // Weight by tier (tier 3 rarer)
    const luck = player.luck;
    const weighted = [];
    for (const u of available) {
      const w = u.tier === 1 ? 10 : u.tier === 2 ? 5 + luck : 2 + luck;
      for (let i = 0; i < w; i++) weighted.push(u);
    }

    const chosen = [];
    const seen = new Set();
    let tries = 0;
    while (chosen.length < count && tries++ < 200) {
      const u = rPick(weighted);
      if (!seen.has(u.id)) { seen.add(u.id); chosen.push(u); }
    }
    return chosen;
  },

  applyEffect(player, id, level) {
    switch (id) {
      case 'sharp_blade':   player.atk += 2; break;
      case 'iron_body':     player.maxHp += 4; player.hp = Math.min(player.hp + 2, player.maxHp); break;
      case 'stoneskin':     player.def += 1; break;
      case 'fleet_foot':    player.speed += 12; break;
      case 'lucky_star':    player.luck += 1; break;
      case 'regeneration':
        player.regenRate = level === 1 ? 1/5 : 1/4;
        break;
      // Others are passive checks in player update / game
    }
  },

  getDesc(id, lvl) {
    const def = UPGRADE_MAP[id];
    if (!def) return '';
    return def.desc(lvl);
  },

  getDef(id) { return UPGRADE_MAP[id]; },
};
