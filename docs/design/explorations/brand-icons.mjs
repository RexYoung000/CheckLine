// Local CheckLine outline study. All paths share a 24-unit grid and rounded joins.
// This is an original presentation study, not an imported icon library.
const symbols={
  user:'<circle cx="12" cy="7.5" r="3.25"/><path d="M5 20v-1.5a7 6.25 0 0 1 14 0V20"/>',
  bell:'<path d="M7 9a5 5 0 0 1 10 0c0 4.5 1.7 5.3 2 7.1.1.5-.3.9-.8.9H5.8c-.5 0-.9-.4-.8-.9C5.3 14.3 7 13.5 7 9Z"/><path d="M10 20a2.25 2.25 0 0 0 4 0M12 2.5V4"/>',
  menu:'<path d="M4.5 6.5h15M4.5 12h15M4.5 17.5h15"/>',
  home:'<path d="m3 10.5 7.7-6.6a2 2 0 0 1 2.6 0l7.7 6.6M5 9.2V19a2 2 0 0 0 2 2h3v-7h4v7h3a2 2 0 0 0 2-2V9.2"/>',
  budget:'<rect x="3.5" y="7" width="14.5" height="14" rx="3"/><path d="M7 3.5h10a3.5 3.5 0 0 1 3.5 3.5v10M7.5 12h6.5M7.5 16h3.5"/>',
  heart:'<path d="M12 20.5C8.8 18.6 3.2 14.9 3.2 9.2a4.9 4.9 0 0 1 8.8-3 4.9 4.9 0 0 1 8.8 3c0 5.7-5.6 9.4-8.8 11.3Z"/>',
  chart:'<rect x="3.5" y="12" width="3.5" height="8.5" rx="1.3"/><rect x="10.25" y="4" width="3.5" height="16.5" rx="1.3"/><rect x="17" y="8" width="3.5" height="12.5" rx="1.3"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  arrow:'<path d="M6 18 18 6M7 6h11v11"/>',
  right:'<path d="m9 5 7 7-7 7"/>',
  info:'<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 7.5h.01"/>',
  coffee:'<path d="M4.5 8.5H17v6A5.5 5.5 0 0 1 11.5 20h-1.5A5.5 5.5 0 0 1 4.5 14.5ZM17 9h1.5a3 3 0 0 1 0 6H17M7 3v2M11 2v3M15 3v2"/>',
  headphones:'<path d="M4 14V11a8 8 0 0 1 16 0v3"/><rect x="3" y="12" width="4" height="8" rx="2"/><rect x="17" y="12" width="4" height="8" rx="2"/>',
  book:'<path d="M12 6.5c-2-2-5.6-2.8-9-2v14c3.4-.8 7 0 9 2 2-2 5.6-2.8 9-2v-14c-3.4-.8-7 0-9 2Zm0 0v14"/>',
  globe:'<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
  star:'<path d="m12 3 2.7 5.7 6.3.8-4.6 4.4 1.1 6.2-5.5-3-5.5 3 1.1-6.2L3 9.5l6.3-.8Z"/>',
  tent:'<path d="m10 3 11 17H3L14 3M8 20l4-6 4 6"/>',
  wave:'<path d="M3 7c3-4 6 4 9 0s6 4 9 0M3 12c3-4 6 4 9 0s6 4 9 0M3 17c3-4 6 4 9 0s6 4 9 0"/>'
};
export function icon(name,extraClass=''){
  const key=Object.hasOwn(symbols,name)?name:'info';
  const classes=String(extraClass).replace(/[^a-zA-Z0-9_ -]/g,'');
  return `<svg class="app-icon icon-outline ${classes}" data-icon="${key}" data-icon-family="checkline-outline-study" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${symbols[key]}</svg>`;
}
