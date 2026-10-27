/* Static optics around the existing cover. No listeners, storage or motion. */
function wmWishFront(w,completion=false){
  const front=wishFaceFront(w),cover=wishCoverOf(w);
  if(w.achieved||completion||(cover.type==='photo'&&cover.mode==='fill'))return front;
  return front
    .replace('class="wish-front-layout ', 'class="wish-front-layout wish-layered-front ')
    .replace('<div class="wish-front-title">','<span class="wish-front-depth" aria-hidden="true"></span><div class="wish-front-title">')
    .replace('<div class="wish-front-value">','<span class="wish-front-glass" aria-hidden="true"></span><div class="wish-front-value">');
}

// Preserve the row's original content, coverage liquid and single button.
// Its optical layers share the front's roles without replacing its layout.
function wmWishCollectionRow(w){
  const row=wishCollectionRow(w);
  if(w.achieved)return row;
  return row
    .replace('class="wish-collection-row ', 'class="wish-collection-row wish-layered-front ')
    .replace('>','><span class="wish-front-depth" aria-hidden="true"></span>')
    .replace('</button>','<span class="wish-front-glass" aria-hidden="true"></span></button>');
}
