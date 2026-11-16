// Run inside `ego-browser nodejs`; these are browser checks of the isolated sample.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
export const directory = path.dirname(fileURLToPath(import.meta.url));
export const evidence = path.join(directory, 'evidence');
const base = 'http://127.0.0.1:8877/card-library-2026-11-13/capture.html?';
export const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
export function assert(value, message) { if (!value) throw new Error(message); }
export async function open(p, query) {
  const { direct, ...options } = query;
  await p.cdp('Emulation.clearDeviceMetricsOverride');
  await p.goto((direct ? base.replace('capture.html','index.html') : base) + new URLSearchParams(options));
  if (direct) await p.cdp('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: false });
  await p.waitForFunction(() => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview, undefined, { timeout: 10000 });
  await p.cdp('Page.bringToFront');
  await p.evaluate(() => {
    const w = (document.querySelector('iframe')?.contentWindow || window);
    w.__libraryErrors = [];
    w.addEventListener('error', e => w.__libraryErrors.push(e.message));
  });
}
export async function state(p) { return p.evaluate(() => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot()); }
export async function rect(p, selector) {
  return p.evaluate(selector => {
    const f = document.querySelector('iframe'), a = f?.getBoundingClientRect() || { x: 0, y: 0 }, b = (f?.contentDocument || document).querySelector(selector)?.getBoundingClientRect();
    if (!b) throw new Error('Missing visible input target: ' + selector);
    return { x: a.x + b.x, y: a.y + b.y, width: b.width, height: b.height };
  }, selector);
}
export async function click(p, selector) {
  const r = await rect(p, selector), frame = await p.evaluate(() => document.querySelector('iframe')?.getBoundingClientRect().toJSON() || { x:0,right:innerWidth });
  const x = Math.max(frame.x + 10, Math.min(frame.right - 10, r.x + r.width / 2)), y = r.y + r.height / 2;
  await p.cdp('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await p.cdp('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  await p.cdp('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 });
}
export async function flow(p, theme, recording = false) {
  const checkpoints = [];
  const capture = async name => { checkpoints.push({ name, ...await state(p) }); };
  const waitHome = () => stable(p, () => { const s = (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot(); return !s.library && s.phase === 'connected'; });
  const waitFocus = id => stable(p, id => { const s = (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot(); return s.focused === id && !s.browsing; }, id);
  const dwell = pause;
  await open(p, { theme, view: 'home', direct: true });
  const actions = async () => {
    await dwell(650);
    await click(p, '.reader-level-down');
    await stable(p, () => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().library);
    await dwell(450);
    await drag(p, -215, 0); await waitFocus('trip'); await capture('browse-trip');
    await dwell(300);
    await drag(p, -215, 0); await waitFocus('learning'); await capture('browse-learn');
    assert((await state(p)).selected === 'month', 'Browsing changed home selection');
    await dwell(400);
    await drag(p, 0, 36, { duration: 300, hold: async () => {
      const s = await state(p); assert(s.progress > 0, 'Short pull did not follow input');
      assert(await p.evaluate(() => { const w = (document.querySelector('iframe')?.contentWindow || window); return w.getComputedStyle(w.document.querySelector('.machine-unit')).opacity === '0'; }), 'Holder appeared during short pull');
      await dwell(220);
    }});
    await stable(p, () => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().progress === 0);
    await capture('short-pull-cancelled');
    assert((await state(p)).selected === 'month' && (await state(p)).focused === 'learning', 'Cancel lost focus or committed');
    await dwell(400);
    await drag(p, 0, 110, { duration: 450, hold: async () => { await capture('pulling'); await dwell(180); } });
    await waitHome(); await capture('landed');
    const landed = await state(p);
    assert(landed.selected === 'learning' && landed.commits === 1, 'Return did not commit current card exactly once');
    await dwell(700);
    await click(p, '.reader-level-down');
    await waitFocus('learning'); await capture('reentered');
    assert((await state(p)).selected === (await state(p)).focused, 'Reentry lost selected card');
    await dwell(500);
  };
  const media = recording ? await record(p, theme + '-flow', actions) : (await actions(), null);
  await fs.writeFile(path.join(evidence, theme + '-flow-checks.json'), JSON.stringify(checkpoints, null, 2));
  return { checkpoints, media };
}
export async function drag(p, dx, dy, { selector = '.cll-slot[data-centered=true]', duration = 420, hold, reverse = false } = {}) {
  const r = await rect(p, selector), x = r.x + r.width / 2 + (dx < 0 ? Math.min(65, r.width / 4) : dx > 0 ? -Math.min(65, r.width / 4) : 0), y = r.y + r.height / 2;
  await p.cdp('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await p.cdp('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  const steps = Math.max(6, Math.round(duration / 28));
  for (let i = 1; i <= steps; i++) {
    await p.cdp('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x + dx * i / steps, y: y + dy * i / steps, button: 'left', buttons: 1 });
    await pause(duration / steps);
  }
  if (hold) await hold();
  if (reverse) {
    for (let i = steps - 1; i >= 0; i--) {
      await p.cdp('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x + dx * i / steps, y: y + dy * i / steps, button: 'left', buttons: 1 });
      await pause(duration / steps);
    }
  }
  await p.cdp('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x + (reverse ? 0 : dx), y: y + (reverse ? 0 : dy), button: 'left', buttons: 0, clickCount: 1 });
}
export async function shot(p, name) {
  const clip = await p.evaluate(() => { const r = (document.querySelector('iframe') || document.querySelector('.app')).getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height }; });
  return p.screenshot({ path: path.join(evidence, name + '.png'), clip });
}
export async function stable(p, expression, argument = null) {
  // Keep each page command short so screencast frames can be acknowledged
  // throughout the transition rather than only after the final state.
  const started = Date.now();
  while (!await p.evaluate(expression, argument)) {
    if (Date.now() - started > 7000) throw new Error('Preview state timed out');
    await pause(24);
  }
}
export async function checkLayout(p) {
  return p.evaluate(() => {
    const f = document.querySelector('iframe'), w = f.contentWindow, d = f.contentDocument;
    const card = d.querySelector('.cll-slot[data-centered=true]'), stage = d.querySelector('.cll-stage'), footer = d.querySelector('.cll-footer');
    const b = card?.getBoundingClientRect(), s = stage?.getBoundingClientRect(), foot = footer?.getBoundingClientRect();
    const details = [...d.querySelectorAll('.cll-card-used,.cll-card-pending')].length;
    return {
      state: w.CheckLineLibraryPreview.snapshot(), card: card?.innerText || null,
      period: d.querySelector('.cll-period')?.innerText || null,
      titleCount: [...d.querySelectorAll('h2')].filter(x => x.textContent === '预算卡').length,
      removedDetails: details === 0,
      holderHidden: !d.querySelector('.machine-unit') || w.getComputedStyle(d.querySelector('.machine-unit')).opacity === '0',
      cardFits: !b || b.x >= -1 && b.right <= w.innerWidth + 1 && b.y >= s.y - 1 && b.bottom <= s.bottom + 1,
      footerFits: !foot || foot.bottom < w.innerHeight - 65,
      textFits: !card || [...card.querySelectorAll('.cll-card-name,.cll-card-label,.cll-card-amount')].every(e => { const r = e.getBoundingClientRect(); return r.x >= b.x + 10 && r.right <= b.right - 10 && r.y >= b.y + 10 && r.bottom <= b.bottom - 10 && e.scrollWidth <= e.clientWidth + 1; }),
      large: d.querySelector('.app').classList.contains('large-text'),
      errors: w.__libraryErrors,
    };
  });
}
export async function matrix(p) {
  await fs.mkdir(evidence, { recursive: true });
  const results = [];
  for (const theme of ['light', 'dark']) {
    for (const sample of ['normal', 'single', 'many', 'empty', 'long', 'pending', 'over', 'pending-over', 'upcoming', 'due', 'no-deadline', 'zero', 'full']) {
      await open(p, { theme, view: 'library', sample });
      await stable(p, () => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().library);
      const result = await checkLayout(p); results.push({ theme, sample, ...result });
      if (['normal', 'long', 'over', 'pending-over', 'upcoming', 'empty'].includes(sample)) await shot(p, theme + '-' + sample);
      for (const key of ['removedDetails', 'holderHidden', 'cardFits', 'footerFits', 'textFits']) assert(result[key], theme + '/' + sample + ': ' + key);
      assert(result.titleCount === 0 && result.errors.length === 0, 'Unexpected title or runtime error');
    }
    for (const [width, height, text, reduce] of [[320,640,'',''],[320,640,'large','1'],[390,844,'large',''],[768,1024,'','1']]) {
      await open(p, { theme, view: 'library', width, height, text, reduce });
      await stable(p, () => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().library);
      const result = await checkLayout(p); results.push({ theme, width, height, text, reduce, ...result });
      await shot(p, `${theme}-${width}-${text || 'normal'}-${reduce || 'motion'}`);
      for (const key of ['cardFits', 'footerFits', 'textFits']) assert(result[key], theme + '/' + width + '/' + text + ': ' + key);
    }
  }
  await fs.writeFile(path.join(evidence, 'layout-checks.json'), JSON.stringify(results, null, 2));
  return { cases: results.length, passed: true };
}
export async function extraInteractions(p) {
  const results = [];
  const home = () => stable(p, () => { const s = (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot(); return !s.library && s.phase === 'connected'; });
  const saved = async name => { results.push({ name, ...await state(p) }); };
  await open(p, { theme: 'light', view: 'library' });
  await drag(p, 0, 110, { reverse: true });
  await stable(p, () => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().progress === 0);
  assert((await state(p)).commits === 0 && (await state(p)).library, 'Reverse drag committed'); await saved('reverse-drag-cancel');
  // Re-grab a short cancelled return, then release without choosing a new axis.
  await drag(p, 0, 52, { duration: 200 });
  const r = await rect(p, '.cll-stage'), x = r.x + r.width / 2, y = r.y + 20;
  await p.cdp('Input.dispatchMouseEvent', { type:'mousePressed', x, y, button:'left', buttons:1, clickCount:1 });
  await p.cdp('Input.dispatchMouseEvent', { type:'mouseReleased', x, y, button:'left', buttons:0, clickCount:1 });
  await stable(p, () => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().progress === 0);
  assert(await p.evaluate(() => !(document.querySelector('iframe')?.contentDocument || document).querySelector('.cll-flight')), 'Interrupted cancel stranded a ghost'); await saved('cancel-interrupted-by-tap');
  await click(p, '.cll-slot[data-slot="1"]');
  await stable(p, () => { const s=(document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot();return s.focused==='trip'&&!s.browsing; });
  assert((await state(p)).selected==='month', 'Side tap selected early'); await saved('side-tap-centers');
  await click(p, '.cll-slot[data-centered=true]'); await home();
  assert((await state(p)).selected==='trip'&&(await state(p)).commits===1,'Center tap failed');await saved('center-tap-selects');
  await click(p, '.reader-level-down');
  await stable(p, () => (document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().library);
  // Consecutive native Escape events cannot cancel the in-flight commit.
  await p.evaluate(() => (document.querySelector('iframe')?.contentDocument || document).querySelector('.cll-close').focus());
  for(let i=0;i<2;i++) {
    await p.cdp('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
    await p.cdp('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
  }
  await home(); assert((await state(p)).commits===2, 'Duplicate confirmation failed'); await saved('duplicate-confirm-once');
  await click(p, '.reader-level-down'); await click(p, '.cll-find');
  await p.fill('loc=css:.cll-search', '周末');
  assert(await p.evaluate(()=>(document.querySelector('iframe')?.contentDocument || document).querySelectorAll('[data-grid-card]').length===1),'Search did not filter');
  await click(p, '[data-grid-card="trip"]'); await home(); await saved('search-selects');
  await click(p, '.reader-level-down'); await click(p, '.cll-layout');
  await drag(p, 0, 95, {selector:'.loop-dome'});
  assert((await state(p)).mode==='dome'&&(await state(p)).library,'Sphere vertical drag returned home');await saved('sphere-vertical-browses');
  await pause(400);
  await click(p, '.loop-dome-tile[aria-label^="学点新东西"]');
  await stable(p,()=>!!(document.querySelector('iframe')?.contentDocument || document).querySelector('.picker-confirm'));
  await click(p, '.picker-confirm button:first-child');await home();
  assert((await state(p)).selected==='learning','Sphere did not select');await saved('sphere-selects');
  await open(p,{theme:'dark',view:'library',reduce:'1'});
  const canvas = await p.evaluate(()=>(document.querySelector('iframe')?.contentDocument || document).querySelector('.cll-orb__canvas').toDataURL());
  await pause(220);
  assert(canvas===await p.evaluate(()=>(document.querySelector('iframe')?.contentDocument || document).querySelector('.cll-orb__canvas').toDataURL()),'Reduced particles animated');
  await drag(p,-215,0);await drag(p,0,105);await home();
  assert((await state(p)).selected==='trip'&&(await state(p)).commits===1,'Reduced return failed');await saved('reduced-motion-static-and-selectable');
  await open(p,{theme:'light',view:'library',sample:'single'});await drag(p,-215,0);
  assert((await state(p)).focused==='month','Single card changed focus');await click(p,'.cll-close');await home();await saved('single-card-selects');
  await open(p,{theme:'dark',view:'library',sample:'empty'});await click(p,'.cll-close');
  await stable(p,()=>!(document.querySelector('iframe')?.contentWindow || window).CheckLineLibraryPreview.snapshot().library);
  assert((await state(p)).selected===null&&(await state(p)).commits===0,'Empty library fabricated a selection');await saved('empty-library-return');
  await fs.writeFile(path.join(evidence,'interaction-checks.json'),JSON.stringify(results,null,2));
  return {passed:true,checks:results};
}
export async function record(p, name, actions) {
  const folder = path.join(evidence, name + '-frames');
  await fs.mkdir(folder, { recursive: true });
  await p.events();
  const clip = await p.evaluate(() => (document.querySelector('iframe') || document.querySelector('.app')).getBoundingClientRect().toJSON());
  const viewport = await p.evaluate(() => ({ width: innerWidth, height: innerHeight }));
  let running = true, failure, frames = [];
  const started = Date.now() / 1000;
  await p.cdp('Page.startScreencast', { format:'jpeg', quality:90, maxWidth:viewport.width, maxHeight:viewport.height, everyNthFrame:1 });
  const pump = (async () => {
    try {
      while (running) {
        for (const event of await p.events()) {
          if (event.method !== 'Page.screencastFrame') continue;
          const frame = event.params;
          await p.cdp('Page.screencastFrameAck', { sessionId: frame.sessionId });
          if (frame.metadata.timestamp >= started) frames.push({ time:frame.metadata.timestamp, data:frame.data });
        }
        await pause(8);
      }
    } catch (error) { failure = error; }
  })();
  try { await actions(); await pause(700); } finally { running = false; await pump; await p.cdp('Page.stopScreencast'); }
  if (failure) throw failure;
  frames.sort((a,b) => a.time - b.time);
  const capturedFrames = frames.length;
  // CDP can deliver a stale surface immediately after viewport emulation.
  // Exclude it before encoding so the first frame cannot reset video geometry.
  const dimensions = data => {
    const b = Buffer.from(data, 'base64');
    for (let i = 2; i < b.length;) {
      if (b[i] !== 255) { i++; continue; }
      const marker = b[i + 1]; i += 2;
      if (marker === 216 || marker === 217) continue;
      if ([192,193,194].includes(marker)) return { width:b.readUInt16BE(i + 5),height:b.readUInt16BE(i + 3) };
      i += b.readUInt16BE(i);
    }
    return {};
  };
  frames = frames.filter(frame => { const s = dimensions(frame.data); return s.width === viewport.width && s.height === viewport.height; });
  assert(frames.length > 1, 'No usable recording frames');
  for (let i = 0; i < frames.length; i++) await fs.writeFile(path.join(folder, String(i).padStart(5,'0') + '.jpg'), Buffer.from(frames[i].data, 'base64'));
  const entries = frames.map((frame,i) => `file '${String(i).padStart(5,'0')}.jpg'\noption framerate 1000\nduration ${Math.max(.001,(frames[i+1]?.time || frame.time + .1)-frame.time).toFixed(6)}`).join('\n');
  await fs.writeFile(path.join(folder, 'frames.txt'), entries + '\n');
  const metadata = { name, frames: frames.length, excludedStaleFrames:capturedFrames - frames.length, duration: frames.at(-1).time - frames[0].time, clip, viewport, source: 'EgoLite top-level 390x844 CDP screencast; real frames and timestamps, native pointer input, no speed change' };
  await fs.writeFile(path.join(evidence, name + '.json'), JSON.stringify(metadata, null, 2));
  return metadata;
}
