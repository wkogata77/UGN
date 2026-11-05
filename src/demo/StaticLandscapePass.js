import * as THREE from 'three';

// Reuse terrain color AND depth while the camera is still, preserving occlusion.
export class StaticLandscapePass {
  constructor() {
    this.enabled = true;
    this.dirty = true;
    this.captures = 0;
    this.size = new THREE.Vector2();
    this.target = new THREE.WebGLRenderTarget(1, 1, {
      type: THREE.HalfFloatType,
      depthTexture: new THREE.DepthTexture(1, 1, THREE.UnsignedIntType),
    });
    this.material = new THREE.ShaderMaterial({
      uniforms: {
        landscapeColor: { value: this.target.texture },
        landscapeDepth: { value: this.target.depthTexture },
      },
      depthTest: true,
      depthWrite: true,
      depthFunc: THREE.AlwaysDepth,
      vertexShader: `
        varying vec2 screenUv;
        void main() {
          screenUv = uv;
          gl_Position = vec4(position.xy, 0.0, 1.0);
        }
      `,
      fragmentShader: `
        uniform sampler2D landscapeColor;
        uniform sampler2D landscapeDepth;
        varying vec2 screenUv;
        void main() {
          gl_FragColor = texture2D(landscapeColor, screenUv);
          gl_FragDepth = texture2D(landscapeDepth, screenUv).r;
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }
      `,
    });
    this.quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.material);
    this.quad.frustumCulled = false;
    this.scene = new THREE.Scene();
    this.scene.add(this.quad);
    this.camera = new THREE.Camera();
  }
  invalidate() {
    this.dirty = true;
  }
  render(renderer, scene, camera, landscape, dynamic) {
    if (!this.enabled) {
      renderer.render(scene, camera);
      return;
    }
    renderer.getDrawingBufferSize(this.size);
    if (
      this.target.width !== this.size.x ||
      this.target.height !== this.size.y
    ) {
      this.target.setSize(this.size.x, this.size.y);
      this.dirty = true;
    }
    const target = renderer.getRenderTarget(),
      clear = renderer.autoClear;
    const visible = dynamic.map((mesh) => mesh.visible);
    const landscapeVisible = landscape.visible;
    try {
      if (this.dirty) {
        dynamic.forEach((mesh) => {
          mesh.visible = false;
        });
        renderer.setRenderTarget(this.target);
        renderer.autoClear = true;
        renderer.render(scene, camera);
        dynamic.forEach((mesh, i) => {
          mesh.visible = visible[i];
        });
        this.dirty = false;
        this.captures++;
      }
      renderer.setRenderTarget(target);
      renderer.autoClear = true;
      renderer.render(this.scene, this.camera);
      landscape.visible = false;
      renderer.autoClear = false;
      renderer.render(scene, camera);
    } finally {
      landscape.visible = landscapeVisible;
      dynamic.forEach((mesh, i) => {
        mesh.visible = visible[i];
      });
      renderer.setRenderTarget(target);
      renderer.autoClear = clear;
    }
  }
  dispose() {
    this.target.dispose();
    this.material.dispose();
    this.quad.geometry.dispose();
  }
}
