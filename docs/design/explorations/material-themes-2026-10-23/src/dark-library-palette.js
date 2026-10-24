// The arc and sphere use SVG textures. Read the same dark face roles as the
// DOM cards; no new independent palette, geometry or library motion.
function darkIceLibraryPalette(card) {
  const style = getComputedStyle(document.querySelector('.app[data-home-material]'));
  const tint = style.getPropertyValue('--di-card-tint').trim();
  return {
    ink: card.fill > 20 ? '#ffffff' : style.getPropertyValue('--di-ink').trim(),
    title: style.getPropertyValue('--di-ink').trim(),
    top: tint, bottom: tint,
    opacity: style.getPropertyValue('--di-card-alpha').trim(),
    ambient: '#f4fcff', ambientOpacity: .69,
    water1: '#86e2ff33', waterMid: '#0b4c74a3', water2: '#103e58bf',
    rim: '#def8ffb0'
  };
}
