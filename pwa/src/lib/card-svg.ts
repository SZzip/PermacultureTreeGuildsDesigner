import type { PlantData } from './types';

const MONTH_LABELS = ['J','F','M','A','M','J','J','A','S','O','N','D'];

function esc(s: string): string {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

/** Render a colored square for a month calendar row */
function monthBox(x: number, y: number, active: boolean, color: string): string {
  const fill = active ? color : '#e0e0e0';
  return `<rect x="${x}" y="${y}" width="3.8" height="3.8" rx="0.3" fill="${fill}" stroke="#888" stroke-width="0.1"/>`;
}

/** Render a month calendar row (fruit or flower) */
function monthRow(y: number, months: boolean[], color: string, icon: string): string {
  let svg = '';
  // Icon
  svg += `<text x="1" y="${y + 3}" font-size="3" font-family="Arial">${esc(icon)}</text>`;
  for (let i = 0; i < 12; i++) {
    svg += monthBox(6 + i * 4.2, y, months[i], color);
  }
  // Month labels on first row only
  return svg;
}

function monthLabelsRow(y: number): string {
  let svg = '';
  for (let i = 0; i < 12; i++) {
    svg += `<text x="${7.9 + i * 4.2}" y="${y}" font-size="2" font-family="Arial" text-anchor="middle" fill="#666">${MONTH_LABELS[i]}</text>`;
  }
  return svg;
}

/** Render a small icon-badge for a boolean property */
function badge(x: number, y: number, active: boolean, color: string, label: string, labelBelow?: string): string {
  const fill = active ? color : '#ccc';
  let svg = `<rect x="${x}" y="${y}" width="8" height="8" rx="1" fill="${fill}" stroke="#666" stroke-width="0.15"/>`;
  svg += `<text x="${x + 4}" y="${y + 5.5}" font-size="2.8" font-family="Arial" text-anchor="middle" fill="${active ? '#000' : '#999'}">${esc(label)}</text>`;
  if (labelBelow) {
    svg += `<text x="${x + 4}" y="${y + 9.5}" font-size="1.8" font-family="Arial" text-anchor="middle" fill="#666">${esc(labelBelow)}</text>`;
  }
  return svg;
}

function scoreBadge(x: number, y: number, active: boolean, color: string, label: string, score: number): string {
  let svg = badge(x, y, active, color, label);
  if (active && score > 0) {
    svg += `<text x="${x + 8}" y="${y + 3}" font-size="2.2" font-family="Arial" fill="#333">${score}</text>`;
  }
  return svg;
}

/** Section header */
function sectionLabel(x: number, y: number, text: string): string {
  return `<text x="${x}" y="${y}" font-size="2.2" font-family="Arial" font-weight="bold" fill="#444">${esc(text)}</text>`;
}

/** Small pH color bar segment */
function phSegment(x: number, y: number, active: boolean, color: string, label: string): string {
  const opacity = active ? '1' : '0.2';
  let svg = `<rect x="${x}" y="${y}" width="6.5" height="3.5" fill="${color}" opacity="${opacity}" stroke="#888" stroke-width="0.1" rx="0.3"/>`;
  svg += `<text x="${x + 3.25}" y="${y + 2.5}" font-size="1.6" font-family="Arial" text-anchor="middle" fill="#000" opacity="${active ? 1 : 0.4}">${esc(label)}</text>`;
  return svg;
}

export function renderPolyCard(plant: PlantData): string {
  const W = 70;   // mm
  const H = 120;  // mm

  let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}mm" height="${H}mm" viewBox="0 0 ${W} ${H}">`;

  // Background
  svg += `<rect width="${W}" height="${H}" rx="3" fill="#fff" stroke="#333" stroke-width="0.3"/>`;

  // Image placeholder
  if (plant.imageUrl) {
    svg += `<image href="${esc(plant.imageUrl)}" x="0.5" y="0.5" width="${W - 1}" height="40" preserveAspectRatio="xMidYMid slice" clip-path="inset(0 round 2.5px)"/>`;
  } else {
    svg += `<rect x="0.5" y="0.5" width="${W - 1}" height="40" rx="2.5" fill="#d4e8d0"/>`;
    svg += `<text x="${W / 2}" y="22" font-size="4" font-family="Arial" text-anchor="middle" fill="#888">Kein Bild</text>`;
  }

  // Names
  svg += `<text x="${W / 2}" y="46" font-size="3.5" font-family="Arial" font-weight="bold" text-anchor="middle" fill="#222">${esc(plant.commonName || '—')}</text>`;
  svg += `<text x="${W / 2}" y="50" font-size="2.8" font-family="Arial" font-style="italic" text-anchor="middle" fill="#555">${esc(plant.latinName || '—')}</text>`;

  // --- Human usages ---
  const uy = 53;
  svg += sectionLabel(1, uy, 'Nutzung');
  const usages: [boolean, string, string, number?][] = [
    [plant.eatable, '#8bc34a', 'Ess', plant.eatableScore],
    [plant.culinaric, '#e1b2d3', 'Kul'],
    [plant.meds, '#f44336', 'Med', plant.medsScore],
    [plant.material, '#7b6a58', 'Mat', plant.materialScore],
    [plant.fodder, '#79c197', 'Fut'],
    [plant.fuel, '#fbec53', 'Brn'],
  ];
  for (let i = 0; i < usages.length; i++) {
    const [active, color, label, score] = usages[i];
    if (score !== undefined) {
      svg += scoreBadge(1 + i * 11, uy + 1, active, color, label, score);
    } else {
      svg += badge(1 + i * 11, uy + 1, active, color, label);
    }
  }

  // --- Ecosystem ---
  const ey = 64;
  svg += sectionLabel(1, ey, 'Ökosystem');
  const eco: [boolean, string, string][] = [
    [plant.nitrogenFix, '#4caf50', 'N₂'],
    [plant.mineralFix, '#795548', 'Min'],
    [plant.groundCover, '#8d6e63', 'Bod'],
    [plant.insects, '#ff9800', 'Ins'],
    [plant.pest, '#f44336', 'Sch'],
    [plant.animalProtection, '#3f51b5', 'Tie'],
    [plant.windBreaking, '#607d8b', 'Wnd'],
  ];
  for (let i = 0; i < eco.length; i++) {
    svg += badge(1 + i * 9.5, ey + 1, eco[i][0], eco[i][1], eco[i][2]);
  }

  // --- Sun / Water / Growth ---
  const sy = 75;
  svg += sectionLabel(1, sy, 'Sonne');
  const suns: [boolean, string, string][] = [
    [plant.sunFull, '#fdd835', '☀'],
    [plant.sunMid, '#ffee58', '⛅'],
    [plant.sunShadow, '#90a4ae', '☁'],
  ];
  for (let i = 0; i < suns.length; i++) {
    svg += badge(1 + i * 9.5, sy + 1, suns[i][0], suns[i][1], suns[i][2]);
  }

  svg += sectionLabel(30, sy, 'Wasser');
  const waters: [boolean, string, string][] = [
    [plant.waterDry, '#e8d5b7', 'Tro'],
    [plant.waterMid, '#81d4fa', 'Mit'],
    [plant.waterWet, '#1565c0', 'Nas'],
    [plant.waterPlant, '#006064', '🌊'],
  ];
  for (let i = 0; i < waters.length; i++) {
    svg += badge(30 + i * 9.5, sy + 1, waters[i][0], waters[i][1], waters[i][2]);
  }

  // --- Growth speed ---
  const gy = 86;
  svg += sectionLabel(1, gy, 'Wuchs');
  const speeds: [boolean, string, string][] = [
    [plant.growSpeedLow, '#a5d6a7', '▽'],
    [plant.growSpeedMid, '#66bb6a', '△'],
    [plant.growSpeedHigh, '#2e7d32', '▲'],
  ];
  for (let i = 0; i < speeds.length; i++) {
    svg += badge(1 + i * 9.5, gy + 1, speeds[i][0], speeds[i][1], speeds[i][2]);
  }

  // Climate zone
  svg += sectionLabel(30, gy, 'Zone');
  svg += `<text x="42" y="${gy + 6}" font-size="3.5" font-family="Arial" fill="#222">${esc(plant.climateZone || '—')}</text>`;

  // --- pH ---
  const py = 96;
  svg += sectionLabel(1, py, 'pH');
  const phs: [boolean, string, string][] = [
    [plant.phVeryAcid, '#ff5555', 'S.S'],
    [plant.phAcid, '#ffd42a', 'Sau'],
    [plant.phNeutral, '#00d400', 'Neu'],
    [plant.phAlkaline, '#2ca089', 'Alk'],
    [plant.phVeryAlkaline, '#0066ff', 'S.A'],
    [plant.phSaline, '#7f2aff', 'Sal'],
  ];
  for (let i = 0; i < phs.length; i++) {
    svg += phSegment(1 + i * 7, py + 1.5, phs[i][0], phs[i][1], phs[i][2]);
  }

  // --- Months ---
  const my = 103;
  svg += monthLabelsRow(my);
  svg += monthRow(my + 1, plant.fruitMonths, '#ff4444', '🍎');
  svg += monthRow(my + 6, plant.flowerMonths, '#ff66cc', '🌸');

  // --- Height / Width ---
  svg += `<text x="2" y="117" font-size="2.8" font-family="Arial" fill="#333">↕ ${plant.heightM != null ? plant.heightM + 'm' : '—'}</text>`;
  svg += `<text x="25" y="117" font-size="2.8" font-family="Arial" fill="#333">↔ ${plant.widthM != null ? plant.widthM + 'm' : '—'}</text>`;

  svg += '</svg>';
  return svg;
}

export function renderStripeCard(plant: PlantData): string {
  const W = 290;
  const H = 16;

  let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}mm" height="${H}mm" viewBox="0 0 ${W} ${H}">`;
  svg += `<rect width="${W}" height="${H}" rx="1" fill="#fff" stroke="#333" stroke-width="0.2"/>`;

  // Name block
  svg += `<text x="2" y="6" font-size="3.5" font-family="Arial" font-weight="bold" fill="#222">${esc(plant.commonName || '—')}</text>`;
  svg += `<text x="2" y="10" font-size="2.5" font-family="Arial" font-style="italic" fill="#555">${esc(plant.latinName || '—')}</text>`;

  // Dimensions
  svg += `<text x="55" y="6" font-size="2.5" font-family="Arial" fill="#333">↕${plant.heightM ?? '—'}m</text>`;
  svg += `<text x="55" y="10" font-size="2.5" font-family="Arial" fill="#333">↔${plant.widthM ?? '—'}m</text>`;

  // Fruit months (compact)
  for (let i = 0; i < 12; i++) {
    const fill = plant.fruitMonths[i] ? '#ff4444' : '#eee';
    svg += `<rect x="${70 + i * 3.5}" y="1.5" width="3" height="5.5" rx="0.3" fill="${fill}" stroke="#aaa" stroke-width="0.1"/>`;
    svg += `<text x="${71.5 + i * 3.5}" y="5" font-size="1.8" font-family="Arial" text-anchor="middle" fill="#666">${MONTH_LABELS[i]}</text>`;
  }

  // Flower months
  for (let i = 0; i < 12; i++) {
    const fill = plant.flowerMonths[i] ? '#ff66cc' : '#eee';
    svg += `<rect x="${70 + i * 3.5}" y="8.5" width="3" height="5.5" rx="0.3" fill="${fill}" stroke="#aaa" stroke-width="0.1"/>`;
  }

  // Usages compact
  const compactBadges: [boolean, string, string][] = [
    [plant.eatable, '#8bc34a', 'E'],
    [plant.meds, '#f44336', 'M'],
    [plant.material, '#7b6a58', 'W'],
    [plant.nitrogenFix, '#4caf50', 'N'],
    [plant.groundCover, '#8d6e63', 'B'],
    [plant.insects, '#ff9800', 'I'],
    [plant.windBreaking, '#607d8b', 'Wi'],
  ];
  for (let i = 0; i < compactBadges.length; i++) {
    const [active, color, label] = compactBadges[i];
    const fill = active ? color : '#ddd';
    svg += `<rect x="${115 + i * 6}" y="3" width="5" height="5" rx="0.5" fill="${fill}" stroke="#888" stroke-width="0.1"/>`;
    svg += `<text x="${117.5 + i * 6}" y="6.8" font-size="2" font-family="Arial" text-anchor="middle" fill="${active ? '#000' : '#aaa'}">${label}</text>`;
  }

  // Sun/Water/pH compact
  const env: [boolean, string, string][] = [
    [plant.sunFull, '#fdd835', '☀'],
    [plant.sunMid, '#ffee58', '⛅'],
    [plant.sunShadow, '#90a4ae', '☁'],
    [plant.waterDry, '#e8d5b7', 'T'],
    [plant.waterMid, '#81d4fa', 'M'],
    [plant.waterWet, '#1565c0', 'N'],
  ];
  for (let i = 0; i < env.length; i++) {
    const [active, color, label] = env[i];
    const fill = active ? color : '#ddd';
    svg += `<rect x="${160 + i * 6}" y="3" width="5" height="5" rx="0.5" fill="${fill}" stroke="#888" stroke-width="0.1"/>`;
    svg += `<text x="${162.5 + i * 6}" y="6.8" font-size="2" font-family="Arial" text-anchor="middle" fill="${active ? '#000' : '#aaa'}">${label}</text>`;
  }

  // Zone
  svg += `<text x="200" y="8" font-size="2.8" font-family="Arial" fill="#333">Zone: ${esc(plant.climateZone || '—')}</text>`;

  // pH bar
  const phColors: [boolean, string][] = [
    [plant.phVeryAcid, '#ff5555'],
    [plant.phAcid, '#ffd42a'],
    [plant.phNeutral, '#00d400'],
    [plant.phAlkaline, '#2ca089'],
    [plant.phVeryAlkaline, '#0066ff'],
    [plant.phSaline, '#7f2aff'],
  ];
  for (let i = 0; i < phColors.length; i++) {
    const opacity = phColors[i][0] ? '1' : '0.15';
    svg += `<rect x="${225 + i * 5}" y="3" width="4.5" height="5" rx="0.3" fill="${phColors[i][1]}" opacity="${opacity}" stroke="#888" stroke-width="0.1"/>`;
  }

  // Growth speed
  const gs = plant.growSpeedHigh ? '▲' : plant.growSpeedMid ? '△' : plant.growSpeedLow ? '▽' : '—';
  svg += `<text x="260" y="8" font-size="3" font-family="Arial" fill="#333">${gs}</text>`;

  svg += '</svg>';
  return svg;
}
