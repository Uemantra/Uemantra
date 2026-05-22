# 🐱 Kitty Tanks 💣

A turn-based kitten artillery game for two players on a local network.  
Think Worms meets Pocket Tanks — but with cats and absolutely unhinged weapons.

---

## How to Play

### First Time Setup

1. Install **Node.js** from https://nodejs.org/ (LTS version) on **your** PC.
2. Double-click **`START_SERVER.bat`** — it installs dependencies automatically.

### Every Time You Play

1. **You (Player 1):** Double-click `START_SERVER.bat`.  
   The console will show an address like `http://192.168.x.x:3000` — share that with your wife.
2. **You:** Open `http://localhost:3000` in your browser.
3. **Wife (Player 2):** Open the shared address in her browser on her PC.
4. Once both players connect, the game starts automatically!

---

## Controls

| Action | Key / Mouse |
|--------|-------------|
| Move left / right | `A` / `D` or Arrow keys |
| Aim | Move your mouse |
| Fire! | Left click |
| Select weapon | `1`–`8` number keys or click the weapon bar |
| Skip turn (no fire) | `E` |

---

## Weapons

| # | Weapon | Ammo | Description |
|---|--------|------|-------------|
| 1 | 🧶 Yarn Ball | ∞ | Classic — bounces once before exploding |
| 2 | 🤮 Hairball Bomb | 3 | Big, slow, disgusting, and very powerful |
| 3 | 🌿 Catnip Cloud | 2 | Low damage, but reverses opponent's controls next turn! |
| 4 | 🚀 Hiss Missile | 2 | Heat-seeking — chases the enemy kitty |
| 5 | ⚡ Midnight Zoomies | 1 | Fires **5 random** yarn balls — pure chaos |
| 6 | 🔴 Laser Pointer | 2 | Guide a laser with your mouse for 3.5 seconds |
| 7 | 🐟 Dead Fish Slap | 2 | Massive damage — must be within 170px! |
| 8 | 🎯 Triple Yarn | 2 | Three yarn balls in a spread |

---

## Tips

- **Move first, then aim.** You have a movement budget each turn — use it wisely.
- The **wind** changes every turn — check the indicator in the top center.
- The **Laser Pointer** is great for finishing off a weakened opponent.
- The **Dead Fish Slap** is hilarious if you can get close enough.
- When hit by **Catnip Cloud**, your movement keys are reversed next turn. Don't panic!

---

## Technical Notes

- The server runs on your PC and hosts the game.
- Both players connect via the same local Wi-Fi network.
- No internet required.
- To play again: click **"Play Again!"** after a game ends.
