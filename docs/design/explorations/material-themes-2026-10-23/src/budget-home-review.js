// Keep the review wrapper out of the product screen. The paired page supplies
// viewport and theme controls; existing product actions are left intact.
document.body.classList.add('material-embedded');
document.querySelectorAll('.material-compare').forEach(a=>a.href='budget-home-pair.html');
// Review-only deep link; select the existing collection without changing data.
const hmReviewQuery=new URL(location.href).searchParams;
if(hmReviewQuery.get('view')==='wish'&&hmReviewQuery.get('collection')==='done'){
  wishCollection.phase='done';render();
}
hmStartLiquid();
dmStartDetail();
wmStartCollectionMetal();
