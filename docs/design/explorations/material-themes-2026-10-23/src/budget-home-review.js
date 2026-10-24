// Keep the review wrapper out of the product screen. The paired page supplies
// viewport and theme controls; existing product actions are left intact.
document.body.classList.add('material-embedded');
document.querySelectorAll('.material-compare').forEach(a=>a.href='budget-home-pair.html');
hmStartLiquid();
dmStartDetail();
