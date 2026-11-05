export class FrameInvalidation {
  constructor() {
    this.dirty = true;
  }
  invalidate() {
    this.dirty = true;
  }
  consume(active) {
    if (!active && !this.dirty) return false;
    this.dirty = false;
    return true;
  }
}

export const TROOP_DETAILS = {
  low: [4, 6],
  medium: [6, 10],
  high: [10, 16],
};

export function troopDetail(pixelHeight) {
  return pixelHeight < 22 ? 'low' : pixelHeight < 46 ? 'medium' : 'high';
}

export function uploadInstances(attribute, count) {
  if (!count) return;
  attribute.clearUpdateRanges();
  attribute.addUpdateRange(0, count * attribute.itemSize);
  attribute.needsUpdate = true;
}
