// Review-only framing and synthetic data. The product's storage and renderer
// are not edited by this page. Every reload starts from fixture(), without writes.
(() => {
  'use strict';
  let source='';
  const $=id=>document.getElementById(id);
  const replace=(text,before,after)=>{if(text.split(before).length!==2)throw Error('Review boundary missing: '+before.slice(0,70));return text.replace(before,after);};
  function frameHTML({kind,theme,ratio,size='large',before=false,reduce=false}){
    let html=replace(source,'data ||= fixture();',`data = fixture();
      data.expenses = data.expenses.filter(e => e.budgetId !== 'month');
      if (${ratio} < 1) data.expenses.push({id:'optics-sample',merchant:'材质演示',amount:Math.round(300000*(1-${ratio})),budgetAmount:Math.round(300000*(1-${ratio})),currency:'CNY',budgetId:'month',periodStart:data.cards[0].start,date:today(),status:'confirmed',source:'隔离示例'});`);
    html=replace(html,'data-review-storage="checkline-budget-home-material-20261024"','data-review-storage="checkline-optics-isolated-'+kind+'-'+theme+'"');
    html=replace(html,"function persist(){try{localStorage.setItem(STORAGE,JSON.stringify(data));}catch{toast('本页演示存储已满，输入仍保留在当前页面。');}}",'function persist(){}');
    const view=kind==='home'?'home':size==='large'?'wish-back':'wish';
    html=replace(html,'const materialQuery = new URL(location.href).searchParams;',`const materialQuery = new URLSearchParams(${JSON.stringify('theme='+theme+'&view='+view+(reduce?'&reduce=1':''))});`);
    if(kind==='wish'&&size==='large')html=replace(html,'if (card) wishTurnTo(card, 180);','// Review opens the existing enlarged front, without turning it.');
    // Preserve the historical diagnostic baseline: clipped full surface and
    // no full-water motion. These replacements affect only the "before" frame.
    if(before){
      html=replace(html,'hmMaterializeFace(readerLiquidFace(c),c,true)','hmMaterializeFace(readerLiquidFace(c),c,false)');
      html=replace(html,'Math.max(hmLiquidFullness(ratio)*.48,Math.max(0,Math.min(1,ratio/.12,(1-ratio)/.12)))','Math.max(0,Math.min(1,ratio/.12,(1-ratio)/.12))');
      html=replace(html,'--hm-water-headspace:${20*fullness}px','--hm-water-headspace:0px');
      html=replace(html,"if(ratio===0)return 'empty';","if(ratio===0)return 'empty';\n    if(ratio===1)return 'full';");
    }
    const framing=`<style>
      html,body{width:100%!important;min-width:0!important;height:570px!important;overflow:hidden!important}
      .app{height:570px!important;min-height:570px!important}.page{overflow:hidden!important}
      .dock,.budget-home-head,.reader-tiles,.reader-receipts,.reader-level-controls{visibility:hidden!important}
      ${kind==='wish'?`.app:has(.wish-focus-shell)>.page{visibility:hidden!important}.wish-focus-toolbar{visibility:hidden!important}.overlay-shade:has(.wish-focus-shell){background:var(--hm-ground)!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important;align-items:flex-start!important;padding-top:14px!important}.wish-page-head,.wish-balance-bar,.wish-collection-controls,.wish-draft-chip{display:none!important}.wish-grid{margin:72px auto 0!important;width:164.5px!important;grid-template-columns:164.5px!important}.wish-grid>.wish-flip-card:not(:first-child){display:none!important}`:''}
      </style>`;
    return html.replace('</head>',framing+'</head>');
  }
  function mount(id,config){const stage=$(id);stage.dataset.theme=config.theme;const frame=document.createElement('iframe');frame.title=stage.closest('article').querySelector('h3').textContent+' · '+(config.theme==='dark'?'暗色':'浅色');frame.srcdoc=frameHTML(config);stage.replaceChildren(frame);}
  function render(){
    if(!source)return;
    const tab=document.querySelector('[role=tab][aria-selected=true]').dataset.panel;
    for(const stage of document.querySelectorAll('.viewport'))stage.replaceChildren();
    if(tab==='compare'){
      const theme=$('compare-theme').value,ratio=Number($('compare-ratio').value),reduce=$('compare-reduce').checked;
      mount('budget-stage',{kind:'home',theme,ratio,reduce});
      mount('wish-stage',{kind:'wish',theme,ratio,size:$('wish-size').value,reduce});
    }else if(tab==='water'){
      const theme=$('water-theme').value,ratio=Number($('water-ratio').value),reduce=$('water-reduce').checked;
      mount('before-stage',{kind:'home',theme,ratio,before:true,reduce});
      mount('after-stage',{kind:'home',theme,ratio,reduce});
    }
    $('status').textContent='独立示例 · 切换时重置 · 普通预览数据不变 · 此页不包含原生改动';
  }
  const tabs=[...document.querySelectorAll('[role=tab]')];
  tabs.forEach((button,index)=>{
    button.tabIndex=index===0?0:-1;
    button.addEventListener('keydown',event=>{
      const next=event.key==='ArrowRight'?(index+1)%tabs.length:event.key==='ArrowLeft'?(index+tabs.length-1)%tabs.length:event.key==='Home'?0:event.key==='End'?tabs.length-1:null;
      if(next===null)return;event.preventDefault();tabs[next].focus();tabs[next].click();
    });
    button.addEventListener('click',()=>{
    tabs.forEach(b=>{b.setAttribute('aria-selected',String(b===button));b.tabIndex=b===button?0:-1;});
    document.querySelectorAll('[role=tabpanel]').forEach(p=>p.hidden=p.id!==button.dataset.panel);
    history.replaceState(null,'','#'+button.dataset.panel);render();
    });
  });
  document.querySelectorAll('select,input').forEach(e=>e.addEventListener('change',render));
  fetch('budget-home.html',{cache:'no-store'}).then(r=>{if(!r.ok)throw Error('HTTP '+r.status);return r.text();}).then(html=>{
    source=html;
    const target=document.querySelector('[data-panel="'+location.hash.slice(1).replace(/[^a-z]/g,'')+'"]');
    if(target)target.click();else render();
  }).catch(error=>{$('status').className='error';$('status').textContent='对照组件加载失败：'+error.message;});
})();
