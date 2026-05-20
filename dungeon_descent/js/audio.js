'use strict';

const Audio = {
  ctx: null,
  muted: false,
  masterGain: null,

  init() {
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.masterGain = this.ctx.createGain();
      this.masterGain.gain.value = 0.4;
      this.masterGain.connect(this.ctx.destination);
    } catch(e) { /* no audio */ }
  },

  resume() {
    if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
  },

  _osc(type, freq, start, dur, vol, freqEnd) {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime + (start || 0);
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.connect(g); g.connect(this.masterGain);
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (freqEnd) o.frequency.exponentialRampToValueAtTime(freqEnd, t + dur);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.start(t); o.stop(t + dur + 0.01);
  },

  _noise(start, dur, vol) {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime + (start || 0);
    const buf = this.ctx.createBuffer(1, this.ctx.sampleRate * dur, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    const g = this.ctx.createGain();
    src.connect(g); g.connect(this.masterGain);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.start(t); src.stop(t + dur + 0.01);
  },

  play(sfx) {
    if (!this.ctx || this.muted) return;
    switch (sfx) {
      case 'sword':
        this._osc('sawtooth', 280, 0,    0.06, 0.3, 120);
        this._osc('square',   180, 0.02, 0.08, 0.15, 80);
        break;
      case 'enemy_hit':
        this._osc('square', 380, 0, 0.05, 0.25, 200);
        this._noise(0, 0.04, 0.1);
        break;
      case 'player_hit':
        this._osc('square', 120, 0,    0.05, 0.4, 80);
        this._osc('square', 90,  0.04, 0.1,  0.3, 60);
        this._noise(0, 0.12, 0.2);
        break;
      case 'shoot':
        this._osc('sine', 700, 0, 0.08, 0.18, 300);
        this._osc('square', 400, 0, 0.05, 0.1, 200);
        break;
      case 'proj_hit':
        this._osc('square', 250, 0, 0.06, 0.2, 120);
        this._noise(0, 0.05, 0.15);
        break;
      case 'kill':
        this._osc('square',   200, 0,    0.08, 0.2, 80);
        this._osc('sawtooth', 300, 0.05, 0.15, 0.3, 60);
        this._noise(0, 0.1, 0.15);
        break;
      case 'door_open':
        this._osc('sine', 300, 0,    0.08, 0.2, 600);
        this._osc('sine', 450, 0.07, 0.12, 0.2, 900);
        break;
      case 'chest':
        [0, 0.1, 0.2, 0.35].forEach((t, i) => {
          this._osc('sine', [261, 330, 392, 523][i], t, 0.18, 0.3);
        });
        break;
      case 'upgrade':
        [0, 0.08, 0.16, 0.28].forEach((t, i) => {
          this._osc('sine', [392, 523, 659, 784][i], t, 0.25, 0.25);
          this._osc('square', [196, 261, 330, 392][i], t, 0.25, 0.08);
        });
        break;
      case 'heal':
        this._osc('sine', 500, 0, 0.1, 0.25, 800);
        this._osc('sine', 630, 0.06, 0.12, 0.2, 1000);
        break;
      case 'death':
        this._osc('sawtooth', 120, 0,   0.2, 0.5, 40);
        this._osc('square',   80,  0.1, 0.4, 0.3, 30);
        this._noise(0, 0.4, 0.3);
        break;
      case 'boss_hit':
        this._osc('sawtooth', 80, 0, 0.15, 0.5, 40);
        this._noise(0, 0.1, 0.3);
        break;
      case 'boss_enter':
        this._osc('sawtooth', 55, 0,   0.4, 0.6, 40);
        this._osc('square',   110, 0.2, 0.5, 0.4, 55);
        this._osc('square',   165, 0.4, 0.6, 0.3, 80);
        break;
      case 'victory':
        [0, 0.15, 0.3, 0.5, 0.7].forEach((t, i) => {
          this._osc('square', [523, 659, 784, 1047, 1318][i], t, 0.45, 0.2);
          this._osc('sine',   [523, 659, 784, 1047, 1318][i], t, 0.45, 0.15);
        });
        break;
      case 'coin':
        this._osc('sine', 800, 0, 0.06, 0.2, 1200);
        break;
      case 'step':
        this._noise(0, 0.04, 0.04);
        break;
      case 'explosion':
        this._noise(0, 0.3, 0.4);
        this._osc('sawtooth', 60, 0, 0.3, 0.4, 20);
        break;
      case 'poison':
        this._osc('sine', 200, 0, 0.1, 0.15, 160);
        this._noise(0, 0.06, 0.08);
        break;
      case 'stair_up':
        this._osc('sine',   400, 0,    0.12, 0.2,  700);
        this._osc('sine',   550, 0.10, 0.14, 0.2,  900);
        this._osc('sine',   700, 0.22, 0.18, 0.25, 1100);
        this._osc('square', 300, 0,    0.22, 0.07, 600);
        break;
      case 'pit_fall':
        this._osc('sawtooth', 280, 0,    0.18, 0.3, 60);
        this._osc('square',   180, 0.06, 0.22, 0.2, 40);
        this._noise(0, 0.3, 0.25);
        break;
    }
  },

  toggle() {
    this.muted = !this.muted;
    if (this.masterGain) this.masterGain.gain.value = this.muted ? 0 : 0.4;
    return this.muted;
  },
};
