(() => {
  'use strict';

  const colors = {
    shellTop: ['#eaf8fc', '#244f65'],
    shellMid: ['#dbf1f8', '#19384a'],
    shellBase: ['#bcdde9', '#112b3e'],
    frost: ['#ffffff', '#c3f0ff'],
    facet: ['#72aec6', '#8cdbf5'],
    shadow: ['#4c9cbd', '#031321'],
    edge: ['#528ca8', '#89cbe6'],
    waterTop: ['#77d4ed', '#559ab9'],
    waterMid: ['#59bddd', '#246384'],
    waterBase: ['#308eb7', '#0a304f'],
    core: ['#aff2ff', '#65d6ff'],
    rimLight: ['#e9fcff', '#bdefff'],
    ink: ['#102f41', '#edfaff'],
    supportingInk: ['#2c5669', '#c4e6f4'],
    riskInk: ['#704019', '#ffdda9'],
  };

  const bubblePositions = [
    [342, .24, 2.0], [319, .41, 3.4], [371, .53, 1.3],
    [350, .64, 4.1], [365, .82, 2.0], [297, .69, 1.5],
    [283, .86, 2.0], [81, .88, 1.3],
  ];

  let sequence = 0;

  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[char]));

  const liquidFraction = value => Math.min(1, Math.max(0, Number(value) || 0));

  function glyphWidth(value) {
    return Array.from(String(value ?? '')).reduce((width, char) => {
      if (/\p{Mark}/u.test(char)) return width;
      if (/\s/.test(char)) return width + .34;
      if (/[.,:;!iIl'|]/.test(char)) return width + .38;
      if (/[MW@%]/.test(char)) return width + .94;
      if (/[^\u0000-\u024f]/u.test(char)) return width + 1.06;
      return width + .67;
    }, 0);
  }

  function opticalLayers(fill, id, dark) {
    const ref = name => `url(#${id}-${name})`;
    const color = (attribute, role) => {
      const [lightColor, darkColor] = colors[role];
      if (typeof dark === 'boolean') return `${attribute}="${dark ? darkColor : lightColor}"`;
      return `${attribute}="${lightColor}" style="${attribute}:light-dark(${lightColor},${darkColor})"`;
    };
    const gradient = (tag, name, axes, stops) => `<${tag} id="${id}-${name}" ${axes}>${stops.map(([offset, role, opacity]) =>
      `<stop offset="${offset}" ${color('stop-color', role)} stop-opacity="${opacity}"/>`).join('')}</${tag}>`;
    const linear = (name, axes, stops) => gradient('linearGradient', name, axes, stops);
    const radial = (name, axes, stops) => gradient('radialGradient', name, axes, stops);

    const glass = [
      linear('body', 'x1=".08" x2=".82" y1="0" y2="1"', [
        [0, 'shellTop', .96], [.49, 'shellMid', .87], [1, 'shellBase', .93],
      ]),
      radial('cap', 'cx=".08" cy=".04" r=".79" gradientTransform="matrix(1 0 0 .62 0 .015)"', [
        [0, 'frost', .34], [.52, 'frost', .08], [1, 'frost', 0],
      ]),
      linear('side', 'x1="0" x2="1" y1="0" y2="0"', [
        [0, 'facet', .43], [.022, 'frost', .14], [.065, 'facet', 0],
        [.88, 'shadow', 0], [.979, 'shadow', .30], [1, 'facet', .21],
      ]),
      linear('outline', 'x1=".05" x2=".95" y1="0" y2="1"', [
        [0, 'frost', .94], [.32, 'edge', .48], [.70, 'edge', .38], [1, 'rimLight', .88],
      ]),
      linear('upper-refraction', 'x1="0" x2=".90" y1=".7" y2="0"', [
        [0, 'frost', 0], [.17, 'frost', .89], [.51, 'frost', .49], [1, 'frost', 0],
      ]),
      linear('lower-refraction', 'x1="0" x2="1" y1="0" y2="0"', [
        [0, 'facet', 0], [.35, 'facet', .21], [.76, 'rimLight', .88], [1, 'rimLight', 0],
      ]),
    ].join('');

    const headspace = 15;
    const base = 297;
    const depth = (base - headspace) * fill;
    const waterY = base - depth;
    const swell = Math.min(depth * .33, 3.7);
    const wave = `M0 ${waterY} C78 ${waterY + swell}, 110 ${waterY - swell}, 186 ${waterY - swell * .35} S317 ${waterY + swell}, 400 ${waterY - swell * .42}`;
    const surface = `${wave} L400 ${base} H0 Z`;
    const water = fill > 0 ? `<clipPath id="${id}-water-clip"><path d="${surface}"/></clipPath>
      ${linear('water', 'x1="0" x2="0" y1="0" y2="1"', [
        [0, 'waterTop', .37], [.44, 'waterMid', .43], [1, 'waterBase', .66],
      ])}
      ${radial('core', 'gradientUnits="userSpaceOnUse" cx="278" cy="296" r="214" gradientTransform="matrix(1 0 0 .47 0 157)"', [
        [0, 'core', .78], [.39, 'core', .37], [1, 'core', 0],
      ])}
      ${linear('waterline', 'x1="0" x2="1" y1="0" y2="0"', [
        [0, 'frost', .22], [.18, 'frost', .63], [.49, 'rimLight', .49], [.76, 'rimLight', .80], [1, 'rimLight', .36],
      ])}
      ${radial('bubble', 'cx=".3" cy=".22" r=".75"', [
        [0, 'frost', .34], [.48, 'frost', .04], [1, 'facet', .29],
      ])}` : '';

    const bubbles = bubblePositions.filter(([, , radius]) => depth > radius * 5 + 8)
      .map(([x, height, radius]) => {
        const y = waterY + 5 + (depth - 10) * height;
        return `<circle cx="${x}" cy="${y}" r="${radius}" fill="${ref('bubble')}" ${color('stroke', 'rimLight')} stroke-opacity=".57" stroke-width=".65"/>
          <circle cx="${x - radius * .31}" cy="${y - radius * .39}" r="${radius * .20}" ${color('fill', 'frost')} fill-opacity=".79"/>`;
      }).join('');

    return `<defs>${glass}${water}</defs>
      <rect width="400" height="300" fill="${ref('body')}"/>
      <rect width="400" height="300" fill="${ref('cap')}"/>
      ${fill > 0 ? `<path d="${surface}" fill="${ref('water')}"/>
        <g clip-path="${ref('water-clip')}">
          <rect width="400" height="300" fill="${ref('core')}"/>
          ${bubbles}
        </g>
        <path d="${wave}" transform="translate(0 ${-Math.min(3.6, depth * .26)})" fill="none" ${color('stroke', 'facet')} stroke-opacity=".38" stroke-width=".85"/>
        <path d="${wave}" fill="none" stroke="${ref('waterline')}" stroke-width="1.35"/>` : ''}
      <rect width="400" height="300" fill="${ref('side')}"/>
      <rect x=".8" y=".8" width="398.4" height="298.4" rx="33.2" fill="none" stroke="${ref('outline')}" stroke-width="1.6"/>
      <path d="M6 84 V36 Q6 6 36 6 H245" fill="none" stroke="${ref('upper-refraction')}" stroke-width="1.35" stroke-linecap="round"/>
      <path d="M106 293 H363 Q393 293 393 263 V246" fill="none" stroke="${ref('lower-refraction')}" stroke-width="1.65" stroke-linecap="round"/>`;
  }

  function markup(model, { compact = false } = {}) {
    const line = (name, value) => {
      if (!value) return '';
      const fittedSize = (82 / Math.max(1, glyphWidth(value))).toFixed(2);
      return `<span class="cll-card-${name}" style="--cll-line-size:${fittedSize}cqi">${escape(value)}</span>`;
    };
    const id = `cll-card-${++sequence}`;
    const optics = opticalLayers(liquidFraction(model.fill), id);
    return `<span class="cll-card${compact ? ' cll-card-compact' : ''}" data-id="${escape(model.id)}"${model.upcoming ? ' data-upcoming="true"' : ''}${model.riskText ? ' data-risk="true"' : ''}>
      <svg class="cll-card-optics" viewBox="0 0 400 300" preserveAspectRatio="none" aria-hidden="true" focusable="false">${optics}</svg>
      <span class="cll-card-content">
        ${line('name', model.name)}
        <span class="cll-card-summary">${line('label', model.mainLabel)}${line('amount', model.amountText)}</span>
      </span>
    </span>`;
  }

  function texture(model, dark = false) {
    const line = (value, baseline, maxSize, weight, color) => {
      if (!value) return '';
      const size = Math.min(maxSize, 330 / Math.max(1, glyphWidth(value))).toFixed(2);
      return `<text x="32" y="${baseline}" font-size="${size}" font-weight="${weight}" fill="${colors[color][dark ? 1 : 0]}">${escape(value)}</text>`;
    };
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 400 300">
      <defs><clipPath id="card-shape"><rect width="400" height="300" rx="34"/></clipPath></defs>
      <g clip-path="url(#card-shape)">${opticalLayers(liquidFraction(model.fill), 'card', dark)}</g>
      <g font-family="-apple-system, BlinkMacSystemFont, 'PingFang SC', 'Helvetica Neue', Arial, sans-serif">
        ${line(model.name, 55, 26, 600, 'ink')}
        ${line(model.mainLabel, 215, 17, 500, model.riskText ? 'riskInk' : 'supportingInk')}
        ${line(model.amountText, 265, 44, 620, 'ink')}
      </g>
    </svg>`;
    return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
  }

  function optics(model) {
    return `<svg class="cll-card-optics" viewBox="0 0 400 300" preserveAspectRatio="none" aria-hidden="true" focusable="false">${opticalLayers(liquidFraction(model.fill), 'cll-home-' + (++sequence))}</svg>`;
  }
  window.CheckLineLibraryCard = { markup, texture, optics };
})();
