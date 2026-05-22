class Network {
  constructor() {
    this._handlers = {};
    this.ws = null;
    this.connected = false;
  }

  connect() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const url = `${protocol}//${window.location.host}`;
    this.ws = new WebSocket(url);

    this.ws.addEventListener('open', () => {
      this.connected = true;
      this._emit('connected');
    });

    this.ws.addEventListener('message', (e) => {
      try {
        const msg = JSON.parse(e.data);
        this._emit(msg.type, msg);
        this._emit('*', msg);
      } catch {}
    });

    this.ws.addEventListener('close', () => {
      this.connected = false;
      this._emit('disconnected');
    });

    this.ws.addEventListener('error', () => {
      this._emit('error');
    });
  }

  on(type, fn) {
    if (!this._handlers[type]) this._handlers[type] = [];
    this._handlers[type].push(fn);
    return this;
  }

  _emit(type, data) {
    (this._handlers[type] || []).forEach(fn => fn(data));
  }

  send(data) {
    if (this.connected && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    }
  }
}
