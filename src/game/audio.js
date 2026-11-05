export class BattleAudio {
  constructor(settings) {
    this.settings = settings;
    this.context = null;
    this.lastMarch = 0;
    this.voices = 0;
  }
  unlock() {
    if (!this.settings().sound) return;
    try {
      this.context ||= new (window.AudioContext || window.webkitAudioContext)();
      if (this.context.state === 'suspended')
        this.context.resume().catch(() => {});
    } catch {
      /* Browsers without Web Audio keep the battle silent. */
    }
  }
  play(kind = 'order', x = 720) {
    const settings = this.settings(),
      ctx = this.context;
    if (
      !settings.sound ||
      settings.volume <= 0 ||
      !ctx ||
      ctx.state !== 'running' ||
      this.voices >= 12
    )
      return;
    const duration =
      kind === 'cannon'
        ? 1.1
        : kind === 'musket'
          ? 0.22
          : kind === 'march'
            ? 0.045
            : 0.08;
    const gain = ctx.createGain(),
      pan = ctx.createStereoPanner(),
      filter = ctx.createBiquadFilter();
    pan.pan.value = Math.max(-0.7, Math.min(0.7, (x - 720) / 900));
    filter.type = 'lowpass';
    filter.frequency.value =
      kind === 'cannon' ? 620 : kind === 'musket' ? 2700 : 380;
    const level =
      (kind === 'cannon'
        ? 0.65
        : kind === 'musket'
          ? 0.28
          : kind === 'march'
            ? 0.045
            : 0.05) * settings.volume;
    gain.gain.setValueAtTime(Math.max(0.0001, level), ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + duration);
    filter.connect(gain);
    gain.connect(pan);
    pan.connect(ctx.destination);
    const buffer = ctx.createBuffer(
        1,
        Math.ceil(ctx.sampleRate * duration),
        ctx.sampleRate,
      ),
      data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i++)
      data[i] = (Math.random() * 2 - 1) * Math.exp((-i / data.length) * 3);
    const source = ctx.createBufferSource();
    source.buffer = buffer;
    source.connect(filter);
    this.voices++;
    source.onended = () => {
      this.voices--;
      source.disconnect();
      filter.disconnect();
      gain.disconnect();
      pan.disconnect();
    };
    source.start();
  }
  tick(battle, paused) {
    if (paused || battle.time - this.lastMarch < 0.4) return;
    const moving = battle.units.find((u) => u.visible && u.target && !u.routed);
    if (moving) {
      this.lastMarch = battle.time;
      this.play('march', moving.x);
    }
  }
  destroy() {
    this.context?.close().catch(() => {});
  }
}
