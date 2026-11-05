const ELEVATION_SINE = Math.sin(Math.atan2(1250, 720));

export function cameraMovement(keys, delta, worldPerPixel) {
  const x = Number(keys.has('KeyD')) - Number(keys.has('KeyA'));
  const y = Number(keys.has('KeyS')) - Number(keys.has('KeyW'));
  const length = Math.hypot(x, y);
  if (!length || !Number.isFinite(delta) || delta <= 0) return { x: 0, y: 0 };
  // Screen-space speed stays consistent across zoom levels; stalls cannot jump.
  const step = (Math.min(delta, 0.05) * 480 * worldPerPixel) / length;
  return { x: x * step, y: (y * step) / ELEVATION_SINE };
}
