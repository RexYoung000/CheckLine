// CheckLine achieved-wish optical surface, adapted from React Bits ReflectiveCard.
// Copyright (c) 2026 David Haz. MIT + Commons Clause; full terms:
// ../licenses/ReactBits-ReflectiveCard.txt
// User-provided JS+CSS source SHA-256: 0d9c6181eaa20d1040c34d98fd1aede3d538bf0a3bccd08bdf5065f0a3ebc3f5
// Studio branch only. No React, camera, video, content layout or new gesture owner.
// One WebGL context paints mounted cards into passive 2D layers only when their pose changes.
function wmCreateMetalRenderer(){
  const vertex=`#version 300 es
in vec2 aPosition;
out vec2 vUv;
void main() {
  vUv = aPosition * 0.5 + 0.5;
  gl_Position = vec4(aPosition, 0.0, 1.0);
}`;
  const fragment=`#version 300 es
precision highp float;
in vec2 vUv;
out vec4 fragColor;

uniform vec2 uSize;
uniform float uRadius;
uniform float uScale;
uniform mat3 uRotate;
uniform float uBlur;
uniform float uRough;
uniform float uMetal;
uniform vec3 uTint;
uniform float uWarp;
uniform float uWarpScale;
uniform float uShine;
uniform float uBevel;
uniform float uGlare;
uniform vec2 uPointer;
uniform float uTheme;

const float VIEW = 900.0;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy) * 2.0 - 1.0;
}

vec3 gradientNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
  vec2 ga = hash2(i);
  vec2 gb = hash2(i + vec2(1.0, 0.0));
  vec2 gc = hash2(i + vec2(0.0, 1.0));
  vec2 gd = hash2(i + vec2(1.0, 1.0));
  float va = dot(ga, f);
  float vb = dot(gb, f - vec2(1.0, 0.0));
  float vc = dot(gc, f - vec2(0.0, 1.0));
  float vd = dot(gd, f - vec2(1.0, 1.0));
  float k = va - vb - vc + vd;
  float value = va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k;
  vec2 slope = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd) + du * (u.yx * k + vec2(vb, vc) - va);
  return vec3(value, slope);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float erf(float x) {
  float x2 = x * x;
  return sign(x) * sqrt(1.0 - exp(-x2 * (1.2732395 + 0.147 * x2) / (1.0 + 0.147 * x2)));
}

float band(float x, float halfWidth, float sigma) {
  float s = 1.4142136 * max(sigma, 0.0001);
  return 0.5 * (erf((x + halfWidth) / s) - erf((x - halfWidth) / s));
}

float strip(vec2 q, vec2 center, vec2 dir, float halfWidth, vec2 sigma) {
  vec2 normal = vec2(-dir.y, dir.x);
  return band(dot(q - center, normal), halfWidth, length(sigma * normal));
}

const vec2 SWEEP = vec2(0.5, 0.86);

float softbox(vec2 q, vec2 sigma) {
  float key = strip(q, vec2(-0.1, -0.16), normalize(SWEEP), 0.055, sigma + 0.065);
  float top = band(q.y + 0.35, 0.13, sigma.y + 0.09);
  float side = band(q.x - 0.37, 0.035, sigma.x + 0.05);
  return key * 0.82 + top * 0.65 + side * 0.3;
}

float room(vec2 q, vec2 sigma) {
  // Soft silhouettes behind the key light provide reflected depth, never transmission.
  float fall = smoothstep(-0.4, 0.4, q.y);
  float flag = strip(q, vec2(0.24, -0.02), normalize(SWEEP), 0.09, sigma + 0.08);
  float far = band(q.x + 0.22, 0.035, sigma.x + 0.035) * 0.4;
  far += band(q.x + 0.035 + q.y * 0.08, 0.025, sigma.x + 0.025) * 0.32;
  far += band(q.x - 0.18 - q.y * 0.12, 0.05, sigma.x + 0.045) * 0.48;
  float depth = 1.0 - far * smoothstep(-0.12, 0.32, q.y);
  return mix(0.88, 0.24, fall) * (1.0 - 0.38 * flag) * depth;
}

void main() {
  vec2 p = vec2(vUv.x - 0.5, 0.5 - vUv.y) * uSize;
  vec2 halfSize = uSize * 0.5;
  float r = min(uRadius, min(halfSize.x, halfSize.y));
  vec2 corner = abs(p) - halfSize + r;
  vec2 side = vec2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
  float d;
  vec2 outward;
  if (corner.x > 0.0 && corner.y > 0.0) {
    d = length(corner) - r;
    outward = normalize(corner) * side;
  } else if (corner.x > corner.y) {
    d = corner.x - r;
    outward = vec2(side.x, 0.0);
  } else {
    d = corner.y - r;
    outward = vec2(0.0, side.y);
  }
  float coverage = clamp(0.5 - d * uScale, 0.0, 1.0);

  float chamferWidth = min(uBevel, max(r, 1.0));
  float chamfer = chamferWidth > 0.01 ? 1.0 - smoothstep(0.0, chamferWidth, -d) : 0.0;
  vec2 slope = outward * chamfer;

  vec2 wp = p / (220.0 * uWarpScale);
  vec3 w1 = gradientNoise(wp);
  vec3 w2 = gradientNoise(wp * 2.07 + 13.7);
  vec2 ripple = (w1.yz + w2.yz * 0.5) * uWarp;
  slope += ripple * 0.008;

  float grain = valueNoise(vec2(p.x * 0.008, p.y * 0.55)) * 0.45 + valueNoise(vec2(p.x * 0.019 + 3.7, p.y * 0.23)) * 0.35 + valueNoise(vec2(p.x * 0.004 + 9.2, p.y * 0.09)) * 0.2;
  float brush = uRough * uRough;
  slope.y += (grain - 0.5) * brush * 0.004;

  vec3 normal = uRotate * normalize(vec3(slope, 1.0));
  vec3 position = uRotate * vec3(p, 0.0);
  vec3 view = normalize(position - vec3(0.0, 0.0, max(uSize.x, uSize.y) * 1.55));
  vec3 bounce = reflect(view, normal);
  vec2 q = bounce.xy / max(bounce.z, 0.2);

  vec2 footprint = fwidth(q);
  vec2 sigma = sqrt(vec2(uBlur / VIEW) * vec2(uBlur / VIEW) + footprint * footprint * 0.5);
  sigma += vec2(0.004, 0.05) * uRough;

  vec3 scene = vec3(room(q, sigma));
  scene *= 1.0 + (grain - 0.5) * brush * 0.3;

  vec2 toPointer = (uPointer - p) / (120.0 + uBlur * 4.0);
  vec2 spread = toPointer * vec2(1.0, 1.0 / (1.0 + 2.5 * uRough));
  float reach = dot(spread, spread);
  float glint = max(1.0 + 3.0 * dot(slope, toPointer), 0.0);
  float glare = (exp(-reach * 1.6) + exp(-reach * 0.35) * 0.15) * glint * uGlare * (1.0 + 0.8 * (grain - 0.5) * brush);
  float highlight = (softbox(q, sigma) * uShine + glare) * mix(0.4, 1.0, uMetal);

  vec3 dark = vec3(0.012) + uTint * (scene * 0.16 * uMetal + highlight * 0.34);
  vec3 light = uTint * (0.76 + 0.24 * clamp(scene, 0.0, 1.0)) + vec3(highlight * 0.34);
  vec3 color = mix(dark, light, uTheme);
  color = min(color, 0.7) + 0.3 * (1.0 - exp(-max(color - 0.7, 0.0) / 0.3));
  color = pow(clamp(color, 0.0, 1.0), vec3(1.0 / 2.2));

  color += (hash(gl_FragCoord.xy) - 0.5) / 255.0;
  color = clamp(color, 0.0, 1.0);
  fragColor = vec4(color * coverage, coverage);
}`;
  const surface=document.createElement('canvas');
  const gl=surface.getContext('webgl2',{alpha:true,premultipliedAlpha:true,antialias:false,depth:false,stencil:false});
  if(!gl)return null;
  const shaders=[],program=gl.createProgram();
  for(const [type,source] of [[gl.VERTEX_SHADER,vertex],[gl.FRAGMENT_SHADER,fragment]]){
    const shader=gl.createShader(type);shaders.push(shader);gl.shaderSource(shader,source);gl.compileShader(shader);
    if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS)){shaders.forEach(s=>gl.deleteShader(s));gl.deleteProgram(program);return null;}
    gl.attachShader(program,shader);
  }
  gl.bindAttribLocation(program,0,'aPosition');gl.linkProgram(program);shaders.forEach(s=>gl.deleteShader(s));
  if(!gl.getProgramParameter(program,gl.LINK_STATUS)){gl.deleteProgram(program);return null;}
  const buffer=gl.createBuffer(),vao=gl.createVertexArray();gl.bindVertexArray(vao);gl.bindBuffer(gl.ARRAY_BUFFER,buffer);
  gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,3,-1,-1,3]),gl.STATIC_DRAW);gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,2,gl.FLOAT,false,0,0);
  const u={};for(let i=0;i<gl.getProgramParameter(program,gl.ACTIVE_UNIFORMS);i++){const info=gl.getActiveUniform(program,i);u[info.name]=gl.getUniformLocation(program,info.name);}
  return {
    surface,
    draw(target,{width,height,radius,light,tint,rx,ry,px,py,glare}){
      if(gl.isContextLost())return false;
      const scale=Math.min(devicePixelRatio||1,1.5),w=Math.max(1,Math.round(width*scale)),h=Math.max(1,Math.round(height*scale));
      if(surface.width!==w)surface.width=w;if(surface.height!==h)surface.height=h;
      gl.viewport(0,0,w,h);gl.useProgram(program);gl.bindVertexArray(vao);
      const cx=Math.cos(rx),sx=Math.sin(rx),cy=Math.cos(ry),sy=Math.sin(ry);
      gl.uniformMatrix3fv(u.uRotate,false,new Float32Array([cy,sx*sy,-cx*sy,0,cx,sx,sy,-sx*cy,cx*cy]));
      gl.uniform2f(u.uSize,width,height);gl.uniform2f(u.uPointer,px*width,py*height);gl.uniform3fv(u.uTint,tint);
      for(const [key,value] of Object.entries({uRadius:radius,uScale:scale,uBlur:12,uRough:.32,uMetal:1,uWarp:.52,uWarpScale:1,uShine:.75,uBevel:1.8,uGlare:glare,uTheme:light?1:0}))gl.uniform1f(u[key],value);
      gl.drawArrays(gl.TRIANGLES,0,3);
      if(target.width!==w)target.width=w;if(target.height!==h)target.height=h;
      const ctx=target.getContext('2d');if(!ctx)return false;
      ctx.clearRect(0,0,w,h);ctx.drawImage(surface,0,0);return true;
    },
    dispose(){gl.deleteBuffer(buffer);gl.deleteVertexArray(vao);gl.deleteProgram(program);}
  };
}
function wmStartCollectionMetal(){
  const selector='.wish-is-done .wish-face,.outcome-wish-card .wish-face,.wish-collection-row.is-realized';
  const surfaces=new Map(),media=matchMedia('(prefers-reduced-motion:reduce)');
  let renderer,frame=0,closed=false;
  const angle=(text,axis)=>Number(text.match(new RegExp('rotate'+axis+'\\((-?[\\d.]+)deg\\)'))?.[1]||0)*Math.PI/180;
  function schedule(){if(!closed&&!frame&&!document.hidden)frame=requestAnimationFrame(paint);}
  const resize=new ResizeObserver(schedule);
  function initRenderer(){
    renderer=wmCreateMetalRenderer();
    if(renderer){
      renderer.surface.addEventListener('webglcontextlost',event=>{event.preventDefault();for(const [face,s]of surfaces){s.key='';face.dataset.metalReady='false';}});
      renderer.surface.addEventListener('webglcontextrestored',()=>{renderer.dispose();renderer=undefined;schedule();});
    }
  }
  function paint(){
    frame=0;if(document.hidden||closed)return;
    const next=new Set(app.querySelectorAll(selector));
    for(const [face,s]of surfaces)if(!next.has(face)){resize.unobserve(face);s.canvas.remove();surfaces.delete(face);}
    if(!next.size)return;
    if(renderer===undefined)initRenderer();
    if(!renderer)return;
    for(const face of next){
      let s=surfaces.get(face);
      if(!s){const canvas=document.createElement('canvas');canvas.className='wm-metal-surface';canvas.setAttribute('aria-hidden','true');face.prepend(canvas);s={canvas,key:''};surfaces.set(face,s);resize.observe(face);}
      const width=face.clientWidth,height=face.clientHeight;if(!width||!height)continue;
      const card=face.closest('.wish-flip-card'),isBack=face.classList.contains('wish-face-back');
      const hover=card?.querySelector('.wish-hover-layer')?.style.transform||'',turn=card?.querySelector('.wish-turn-rotor')?.style.transform||'';
      const light=app.dataset.theme==='light',still=reducedMotion(),cs=getComputedStyle(card||face);
      const rx=still?0:angle(hover,'X'),ry=still?0:angle(hover,'Y')+angle(turn,'Y')-(isBack?Math.PI:0);
      const gx=parseFloat(cs.getPropertyValue('--wish-glare-x')),gy=parseFloat(cs.getPropertyValue('--wish-glare-y'));
      const px=still?-.2:(Number.isFinite(gx)?gx:30)/100-.5;
      const py=still?-.3:(Number.isFinite(gy)?gy:20)/100-.5;
      const tintHex=cs.getPropertyValue('--wc-tint').trim();
      const tint=/^#[0-9a-f]{6}$/i.test(tintHex)?[1,3,5].map(i=>Math.pow(parseInt(tintHex.slice(i,i+2),16)/255,2.2)):[1,1,1];
      const opts={width,height,radius:parseFloat(getComputedStyle(face).borderTopLeftRadius)||28,light,tint,rx,ry,px,py,glare:hover&&!still?.16:0};
      const key=JSON.stringify(opts);if(key===s.key)continue;
      if(renderer.draw(s.canvas,opts)){s.key=key;face.dataset.metalReady='true';s.canvas.dataset.paint=String(Number(s.canvas.dataset.paint||0)+1);}
      else face.dataset.metalReady='false';
    }
  }
  // Read existing pose/style writes; never install a competing pointer/turn loop.
  const observer=new MutationObserver(records=>{
    if(records.some(r=>r.type==='childList'||r.target===app||r.target.closest?.('.wish-is-done,.outcome-wish-card,.wish-collection-row.is-realized')))schedule();
  });
  observer.observe(app,{subtree:true,childList:true,attributes:true,attributeFilter:['style','class','data-theme']});
  media.addEventListener('change',schedule);
  document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelAnimationFrame(frame);frame=0;}else schedule();});
  window.addEventListener('pagehide',event=>{cancelAnimationFrame(frame);frame=0;if(!event.persisted){closed=true;observer.disconnect();resize.disconnect();renderer?.dispose();surfaces.clear();}});
  window.addEventListener('pageshow',schedule);schedule();
}
