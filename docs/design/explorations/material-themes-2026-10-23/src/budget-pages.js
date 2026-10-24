// Presentation adapters only. Keep the frozen route functions, calculations,
// confirmation gates and navigation; mark their returned sections for styling.
function smInstallPages(){
  const mark=(render,name)=>function(...args){
    return render(...args).replace('<section class="detail-page"','<section class="detail-page dm-subpage dm-'+name+'"');
  };
  readerRecordsPage=mark(readerRecordsPage,'records');
  recordDetail=mark(recordDetail,'record');
  trendPage=mark(trendPage,'calendar');
  historyPage=mark(historyPage,'history');
  historyDetail=mark(historyDetail,'period');
  infoPage=mark(infoPage,'info');
  Object.assign(readerDrawerRoutes,{record:recordDetail,trend:trendPage,history:historyPage,'history-detail':historyDetail,info:infoPage});

  // The existing progress, fill level, bubble positions and motion are retained.
  // Only replace the outlined dots with the accepted transparent sphere artwork,
  // and reflect a fine white light from the existing vertical free surface.
  const originalLiquid=wishLiquid;
  wishLiquid=function(...args){
    let markup=originalLiquid(...args).replace(/<i (style="[^"]*")><\/i>/g,(_,style)=>'<i '+style+'>'+hmBubbleSvg()+'</i>');
    const fill=args[1]?1:args[0].ratio;
    markup=markup.replace('class="wish-card-liquid ', 'data-wm-tone="'+(fill>=.72?'deep':'clear')+'" class="wish-card-liquid ');
    if(!args[3])markup=markup.replace(/<path d="([^"]*)" fill="url\(#[^"]*\)"\/>/, (whole,shape)=>{
      const line=shape.split('V430')[0];
      return whole+'<path class="wm-water-reflection" d="'+line+'" fill="none"/>';
    });
    return markup;
  };
}
