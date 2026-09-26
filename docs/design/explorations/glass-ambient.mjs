// Decorative lifetimes stay independent of the selected budget and its data.
export function createAmbientSymbols({host, app, page, icon, reduced, active}) {
  const names = ['coffee', 'headphones', 'book', 'globe', 'heart', 'star', 'tent', 'wave'];
  const layer = document.createElement('div');
  layer.className = 'symbol-backdrop';
  host.replaceChildren(layer);
  const particles = new Set();
  let timer = 0, running = false, staticMode = false, serial = 0;
  const random = (min, max) => min + Math.random() * (max - min);
  const choose = list => list[Math.floor(Math.random() * list.length)];

  function zones() {
    const base = app.getBoundingClientRect();
    const header = page.querySelector('.topbar')?.getBoundingClientRect();
    const card = page.querySelector('.home-card-holder,.create-card')?.getBoundingClientRect();
    if (!header || !card) return [];
    // Compensate for the small scroll parallax applied to the shared backdrop.
    const shift = reduced() ? 0 : Math.min(page.scrollTop, 260) * .12;
    const top = header.bottom - base.top + shift + 9;
    const cardTop = card.top - base.top + shift;
    const bottom = Math.min(322, card.bottom - base.top + shift - 22);
    const result = [];
    if (cardTop - top > 6) result.push({x0:30, x1:base.width-30, y0:top, y1:cardTop-6, sky:true});
    const left = card.left - base.left, right = card.right - base.left;
    if (bottom > top + 25 && left >= 16) result.push({x0:9, x1:Math.max(9,left-9), y0:top+12, y1:bottom});
    if (bottom > top + 25 && base.width-right >= 16) result.push({x0:Math.min(base.width-9,right+9), x1:base.width-9, y0:top+12, y1:bottom});
    return result;
  }

  function spawn(quiet = false) {
    if (particles.size >= (quiet ? 4 : 6)) return;
    const available = zones();
    if (!available.length) return;
    let placement;
    for (let attempt=0; attempt<24; attempt++) {
      const zone = choose(available), x=random(zone.x0,zone.x1), y=random(zone.y0,zone.y1);
      if ([...particles].every(p => Math.hypot(p.x-x,p.y-y)>38)) { placement={zone,x,y}; break; }
    }
    if (!placement) return;
    const {zone,x,y}=placement, inUse=new Set([...particles].map(p=>p.name));
    const name=choose(names.filter(n=>!inUse.has(n))), size=random(17,23);
    const el=document.createElement('span');
    el.className='ambient-symbol';
    el.dataset.symbol=name;
    el.dataset.appearance=String(++serial);
    el.style.cssText=`left:${x}px;top:${y}px;--size:${size}px;--symbol-color:${Math.random()<.5?'#886997':'#947347'};`;
    el.innerHTML=icon(name);
    layer.append(el);
    const particle={el,name,x,y,animation:null};
    particles.add(particle);
    if (quiet) { el.style.opacity='.46'; return; }

    const dx=zone.sky?random(-25,25):random(-3,3), dy=zone.sky?random(-5,5):random(-30,30);
    const angle=random(-21,8), peak=random(.5,.7);
    const pose=(travel,scale,turn)=>`translate(calc(-50% + ${dx*travel}px),calc(-50% + ${dy*travel}px)) rotate(${angle+turn}deg) scale(${scale})`;
    particle.animation=el.animate([
      {offset:0,opacity:0,transform:pose(0,.7,-5)},
      {offset:.2,opacity:peak,transform:pose(.16,1,0)},
      {offset:.67,opacity:peak*.85,transform:pose(.72,1.025,6)},
      {offset:1,opacity:0,transform:pose(1,.9,10)}
    ],{duration:random(4200,7200),easing:'ease-in-out',fill:'both'});
    particle.animation.finished.then(()=>{particles.delete(particle);el.remove();}).catch(()=>{});
  }

  function schedule() {
    clearTimeout(timer);
    if (!running || staticMode) return;
    timer=setTimeout(()=>{spawn();schedule();},random(620,1550));
  }

  function clear() {
    clearTimeout(timer);
    for (const p of particles) { p.animation?.cancel(); p.el.remove(); }
    particles.clear();
  }

  function sync() {
    const nextStatic=reduced(), nextActive=active() && zones().length>0;
    if (nextStatic!==staticMode) { clear(); staticMode=nextStatic; }
    if (staticMode) {
      running=false;
      if (nextActive && !particles.size) for(let i=0;i<4;i++) spawn(true);
      return;
    }
    if (nextActive===running) return;
    running=nextActive;
    if (!running) { clearTimeout(timer); particles.forEach(p=>p.animation?.pause()); return; }
    particles.forEach(p=>p.animation?.play());
    if (!particles.size) { spawn(); spawn(); }
    schedule();
  }

  let width=0, height=0;
  const resize=new ResizeObserver(()=>{
    if (width===app.clientWidth && height===app.clientHeight) return;
    width=app.clientWidth; height=app.clientHeight;
    clear(); running=false; sync();
  });
  resize.observe(app);
  return {sync, destroy(){clear();resize.disconnect();layer.remove();}};
}
