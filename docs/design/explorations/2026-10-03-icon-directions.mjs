// Original CheckLine icon direction study. Not a production asset or approved brand rule.
const line = {
  home: '<path d="m3.5 10 7.1-6a2.2 2.2 0 0 1 2.8 0l7.1 6M5.5 8.5v10a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2v-10M10 20.5v-5a2 2 0 0 1 4 0v5"/>',
  budget: '<path d="M8 3.5h9.5a3.5 3.5 0 0 1 3.5 3.5v9"/><rect x="3" y="7" width="16" height="14" rx="3.5"/><path d="M3.5 15c3-2.5 6 2.5 9 0 2-1.7 4-1.5 6-.5"/>',
  wish: '<path d="M12 20c-2.8-1.8-8.5-5.8-8.5-10.7a4.8 4.8 0 0 1 8.5-3.1 4.8 4.8 0 0 1 8.5 3.1C20.5 14.2 14.8 18.2 12 20Z"/>',
  analysis: '<path d="M5 20v-7M12 20V4M19 20V9"/>',
  user: '<circle cx="12" cy="7.5" r="3.5"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/>',
  bell: '<path d="M6.5 10a5.5 5.5 0 0 1 11 0c0 4 2 4.5 2 6.5h-15c0-2 2-2.5 2-6.5M10 20a2.5 2.5 0 0 0 4 0M12 2.5V4"/>',
  more: '<circle cx="5" cy="12" r=".65"/><circle cx="12" cy="12" r=".65"/><circle cx="19" cy="12" r=".65"/>',
  receipt: '<path d="M6 3.5h12v17l-3-1.7-3 1.7-3-1.7-3 1.7ZM9 8h6M9 12h4"/>',
  calendar: '<rect x="3.5" y="5.5" width="17" height="15" rx="3.5"/><path d="M8 3v5M16 3v5M4 10.5h16M8 15h.01M12 15h.01M16 15h.01"/>',
  history: '<path d="M4 9a8.5 8.5 0 1 1-.1 6M4 4v5h5M12 7.5V12l3 2"/>',
  settings: '<path d="M4 6.5h5M15 6.5h5M4 17.5h9M19 17.5h1"/><circle cx="12" cy="6.5" r="3"/><circle cx="16" cy="17.5" r="3"/>',
  pending: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3 2"/>',
  add: '<path d="M12 4.5v15M4.5 12h15"/>',
  edit: '<path d="m5 15 10.5-10.5a2.8 2.8 0 0 1 4 4L9 19l-5 1ZM13.5 6.5l4 4"/>',
  mic: '<rect x="9" y="3" width="6" height="12" rx="3"/><path d="M6 10.5v1a6 6 0 0 0 12 0v-1M12 18v3M9 21h6"/>',
  send: '<path d="M12 20V4M5.5 10.5 12 4l6.5 6.5"/>',
  photo: '<rect x="3.5" y="3.5" width="17" height="17" rx="3.5"/><circle cx="9" cy="8.5" r="1.5"/><path d="m4 17 5-5 4 4 3-3 4.5 4.5"/>',
  close: '<path d="m6 6 12 12M18 6 6 18"/>',
  back: '<path d="m14.5 4.5-7.5 7.5 7.5 7.5"/>',
  check: '<path d="m5 12 4.5 4.5L19 7"/>'
};
const solid = {
  home: '<path d="M10.1 3.8a3 3 0 0 1 3.8 0l6.3 5.1c1.4 1.1 1 3.1-.6 3.6V19a2 2 0 0 1-2 2H15v-5a3 3 0 0 0-6 0v5H6.4a2 2 0 0 1-2-2v-6.5c-1.6-.5-2-2.5-.6-3.6Z"/>',
  budget: '<path opacity=".55" d="M8 3h10a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3h-1V9a2 2 0 0 0-2-2H5V6a3 3 0 0 1 3-3Z"/><path fill-rule="evenodd" d="M6 7h9a3 3 0 0 1 3 3v9a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3v-9a3 3 0 0 1 3-3Zm-.5 8.4v2c2-1.3 3.6-.6 5.3.1 1.4.6 3 .9 4.7-.5v-2c-2 1.3-3.6.6-5.3-.1-1.4-.6-3-.9-4.7.5Z"/>',
  wish: '<path d="M12 21C9.1 19.2 3 15.1 3 9.4a5.1 5.1 0 0 1 9-3.3 5.1 5.1 0 0 1 9 3.3c0 5.7-6.1 9.8-9 11.6Z"/>',
  analysis: '<rect x="3" y="12" width="4" height="9" rx="2" opacity=".68"/><rect x="10" y="3" width="4" height="18" rx="2"/><rect x="17" y="8" width="4" height="13" rx="2" opacity=".68"/>',
  user: '<circle cx="12" cy="7" r="4"/><path d="M12 13c4.7 0 8 3.1 8 6.8 0 .7-.6 1.2-1.2 1.2H5.2c-.6 0-1.2-.5-1.2-1.2 0-3.7 3.3-6.8 8-6.8Z" opacity=".68"/>',
  bell: '<path d="M5.5 10a6.5 6.5 0 0 1 13 0c0 3.5 2 4.5 2 6.5 0 .6-.5 1-1 1h-15c-.5 0-1-.4-1-1 0-2 2-3 2-6.5Z"/><path d="M9 19h6a3 3 0 0 1-6 0Z" opacity=".68"/>',
  more: '<circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/>',
  receipt: '<path fill-rule="evenodd" d="M7 3h10a2 2 0 0 1 2 2v15.2c0 .7-.8 1.1-1.4.8l-2.6-1.5-3 1.7-3-1.7L6.4 21c-.6.3-1.4-.1-1.4-.8V5a2 2 0 0 1 2-2Zm2 5a1 1 0 0 0 0 2h6a1 1 0 0 0 0-2Zm0 4a1 1 0 0 0 0 2h4a1 1 0 0 0 0-2Z"/>',
  calendar: '<path opacity=".68" d="M3 8a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v2H3Z"/><path d="M7 3a1 1 0 0 1 2 0v4a1 1 0 0 1-2 0Zm8 0a1 1 0 0 1 2 0v4a1 1 0 0 1-2 0Z"/><path fill-rule="evenodd" d="M3 11h18v7a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3Zm4 3v2h2v-2Zm4 0v2h2v-2Zm4 0v2h2v-2Z"/>',
  history: '<path fill-rule="evenodd" d="M4.3 7.5A9 9 0 1 1 3 14a1.1 1.1 0 0 1 2.2-.5 6.8 6.8 0 1 0 1.1-4.7H9a1 1 0 0 1 0 2H3.5A1.5 1.5 0 0 1 2 9.3V4a1 1 0 0 1 2 0v3.5ZM11 7a1 1 0 0 1 2 0v4.5l2.6 1.6a1 1 0 0 1-1.1 1.7l-3-1.9a1 1 0 0 1-.5-.9Z"/>',
  settings: '<rect x="3" y="5.5" width="18" height="2" rx="1" opacity=".68"/><rect x="3" y="16.5" width="18" height="2" rx="1" opacity=".68"/><circle cx="9" cy="6.5" r="3.5"/><circle cx="15" cy="17.5" r="3.5"/>',
  pending: '<path fill-rule="evenodd" d="M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18Zm-1 4v5a1 1 0 0 0 .5.9l3 1.8a1 1 0 0 0 1-1.8L13 11.4V7a1 1 0 0 0-2 0Z"/>',
  add: '<path d="M11 4a1 1 0 0 1 2 0v7h7a1 1 0 0 1 0 2h-7v7a1 1 0 0 1-2 0v-7H4a1 1 0 0 1 0-2h7Z"/>',
  edit: '<path d="m5 14 9-9 5 5-9 9-6 1ZM15 4l1-1a2 2 0 0 1 3 0l2 2a2 2 0 0 1 0 3l-1 1Z"/>',
  mic: '<rect x="8" y="2" width="8" height="13" rx="4"/><path opacity=".68" d="M5 10a1 1 0 0 1 1 1 6 6 0 0 0 12 0 1 1 0 0 1 2 0 8 8 0 0 1-7 7.9V21h2a1 1 0 0 1 0 2H9a1 1 0 0 1 0-2h2v-2.1A8 8 0 0 1 4 11a1 1 0 0 1 1-1Z"/>',
  send: '<path d="M11 20V6.4L6.7 11a1.2 1.2 0 1 1-1.7-1.7l6.1-6.1a1.2 1.2 0 0 1 1.8 0L19 9.3a1.2 1.2 0 1 1-1.7 1.7L13 6.4V20a1 1 0 0 1-2 0Z"/>',
  photo: '<path fill-rule="evenodd" d="M6 3h12a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3Zm2 3a2 2 0 1 0 0 4 2 2 0 0 0 0-4ZM5 17.5V19h14v-1.5l-3.5-4-3.5 3.5-3.5-4Z"/>',
  close: '<path d="M5.2 5.2a1.1 1.1 0 0 1 1.6 0L12 10.4l5.2-5.2a1.1 1.1 0 0 1 1.6 1.6L13.6 12l5.2 5.2a1.1 1.1 0 0 1-1.6 1.6L12 13.6l-5.2 5.2a1.1 1.1 0 0 1-1.6-1.6l5.2-5.2-5.2-5.2a1.1 1.1 0 0 1 0-1.6Z"/>',
  back: '<path d="M14.4 3.7a1.2 1.2 0 0 1 1.7 1.7L9.5 12l6.6 6.6a1.2 1.2 0 0 1-1.7 1.7l-7.4-7.4a1.2 1.2 0 0 1 0-1.8Z"/>',
  check: '<path d="M4.2 11.2a1.2 1.2 0 0 1 1.6 0l3.6 3.6 8.8-8.8a1.2 1.2 0 0 1 1.6 1.6l-9.6 9.6a1.2 1.2 0 0 1-1.6 0l-4.4-4.4a1.2 1.2 0 0 1 0-1.6Z"/>'
};
export function icon(key, style) {
  if (!line[key] || !solid[key]) throw new Error(`Missing icon: ${key}`);
  return `<svg viewBox="0 0 24 24" aria-hidden="true" class="glyph" ${style === 'line' ? 'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"' : 'fill="currentColor"'}>${(style === 'line' ? line : solid)[key]}</svg>`;
}
export function mark(style) {
  return `<svg class="appmark" viewBox="0 0 64 64" aria-hidden="true">${style === 'line' ? '<rect width="64" height="64" rx="15" fill="#eae3f2"/><path d="M25 13h18a7 7 0 0 1 7 7v25" fill="none" stroke="#76618e" stroke-width="2.8" stroke-linecap="round"/><rect x="14" y="19" width="31" height="33" rx="8" fill="#faf9f6"/><path d="M14 39c6-6 12 6 18 0 4-4 8-3 13-1v6a8 8 0 0 1-8 8H22a8 8 0 0 1-8-8Z" fill="#76618e"/><rect x="14" y="19" width="31" height="33" rx="8" fill="none" stroke="#76618e" stroke-width="2.8"/>' : '<rect width="64" height="64" rx="15" fill="#76618e"/><path d="M26 12h17a8 8 0 0 1 8 8v20h-4V23a7 7 0 0 0-7-7H26Z" fill="#cfc1df"/><rect x="13" y="20" width="32" height="33" rx="8" fill="#faf9f6"/><path d="M13 39c6-6 12 6 18 0 4-4 9-3 14-1v7a8 8 0 0 1-8 8H21a8 8 0 0 1-8-8Z" fill="#b4a0cb"/>'}</svg>`;
}
export const samples = [ ['home','首页'],['budget','预算'],['wish','心愿'],['analysis','分析'],['receipt','消费'],['calendar','日历'],['history','周期'],['settings','管理'],['edit','填写'],['mic','语音'],['photo','附件'],['pending','待确认'] ];
