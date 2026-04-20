import { PDFDocument } from 'pdf-lib';
import { renderPolyCardToCanvas, renderStripeCardToCanvas } from './card-canvas';
import type { PlantData } from './types';

// Card dimensions in mm
const POLY_MM   = { w: 70,  h: 120 };
const STRIPE_MM = { w: 290, h: 17  };

// mm → PDF points (1 pt = 1/72 inch)
const pt = (mm: number) => mm * 72 / 25.4;

/**
 * Resolve a Wikimedia Special:FilePath URL to a direct upload.wikimedia.org URL.
 */
async function resolveWikimediaUrl(url: string): Promise<string> {
  const match = url.match(/Special:FilePath\/([^?]+)/);
  if (!match) return url;

  const filename = decodeURIComponent(match[1]);
  const apiUrl =
    `https://commons.wikimedia.org/w/api.php?action=query&titles=File:${encodeURIComponent(filename)}` +
    `&prop=imageinfo&iiprop=url&iiurlwidth=400&format=json&origin=*`;

  try {
    const res  = await fetch(apiUrl);
    const data = await res.json();
    const pages = data.query?.pages;
    const page: any = Object.values(pages as object)[0];
    return page?.imageinfo?.[0]?.thumburl || url;
  } catch {
    return url;
  }
}

/** Fetch an image URL and return a data URI. */
async function imageUrlToDataUrl(url: string): Promise<string | null> {
  const resolved = await resolveWikimediaUrl(url);

  try {
    const res = await fetch(resolved, { mode: 'cors' });
    if (res.ok) {
      const blob = await res.blob();
      return await new Promise<string>((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result as string);
        reader.readAsDataURL(blob);
      });
    }
  } catch { /* fall through */ }

  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width  = img.naturalWidth;
      canvas.height = img.naturalHeight;
      canvas.getContext('2d')!.drawImage(img, 0, 0);
      try { resolve(canvas.toDataURL('image/jpeg', 0.85)); }
      catch { resolve(null); }
    };
    img.onerror = () => resolve(null);
    img.src = resolved;
  });
}

async function plantImageDataUrl(plant: PlantData): Promise<string | undefined> {
  if (!plant.imageUrl) return undefined;
  return (await imageUrlToDataUrl(plant.imageUrl)) ?? undefined;
}

/** Convert canvas to PNG bytes for pdf-lib embedding. */
async function canvasToPngBytes(canvas: HTMLCanvasElement): Promise<Uint8Array> {
  return new Promise((resolve) => {
    canvas.toBlob((blob) => {
      blob!.arrayBuffer().then((buf) => resolve(new Uint8Array(buf)));
    }, 'image/png');
  });
}

/** Trigger browser download of PDF bytes. */
function downloadPdf(bytes: Uint8Array, filename: string) {
  const blob = new Blob([bytes], { type: 'application/pdf' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export async function exportCardsPDF(plants: PlantData[]): Promise<void> {
  if (plants.length === 0) return;

  const pdfDoc = await PDFDocument.create();

  // ── Poly cards – portrait A4 ────────────────────────────────────────────────
  const pageW = pt(210), pageH = pt(297), margin = pt(5);
  const cardW = pt(POLY_MM.w), cardH = pt(POLY_MM.h);
  const cols  = Math.floor((pageW - margin) / (cardW + margin));

  let page = pdfDoc.addPage([pageW, pageH]);
  let col = 0, row = 0;

  for (let i = 0; i < plants.length; i++) {
    const x        = margin + col * (cardW + margin);
    const yFromTop = margin + row * (cardH + margin);

    const imgDataUrl = await plantImageDataUrl(plants[i]);
    const canvas     = await renderPolyCardToCanvas(plants[i], imgDataUrl);
    const pngBytes   = await canvasToPngBytes(canvas);
    const pngImage   = await pdfDoc.embedPng(pngBytes);

    page.drawImage(pngImage, {
      x,
      y: pageH - yFromTop - cardH,
      width: cardW,
      height: cardH,
    });

    col++;
    if (col >= cols) {
      col = 0;
      row++;
      if (margin + (row + 1) * (cardH + margin) > pageH) {
        row = 0;
        if (i < plants.length - 1) page = pdfDoc.addPage([pageW, pageH]);
      }
    }
  }

  // ── Stripe cards – landscape A4 ──────────────────────────────────────────────
  const sPageW = pt(297), sPageH = pt(210), sMargin = pt(3);
  const sCardW = pt(STRIPE_MM.w), sCardH = pt(STRIPE_MM.h);

  let sPage = pdfDoc.addPage([sPageW, sPageH]);
  let sy = sMargin; // distance from top of page

  for (const plant of plants) {
    if (sy + sCardH > sPageH - sMargin) {
      sPage = pdfDoc.addPage([sPageW, sPageH]);
      sy = sMargin;
    }
    const imgDataUrl = await plantImageDataUrl(plant);
    const canvas     = await renderStripeCardToCanvas(plant, imgDataUrl);
    const pngBytes   = await canvasToPngBytes(canvas);
    const pngImage   = await pdfDoc.embedPng(pngBytes);

    sPage.drawImage(pngImage, {
      x: sMargin,
      y: sPageH - sy - sCardH,
      width: sCardW,
      height: sCardH,
    });
    sy += sCardH + pt(2);
  }

  downloadPdf(await pdfDoc.save(), 'permaculture-guild-cards.pdf');
}

export async function exportSingleCardPDF(plant: PlantData): Promise<void> {
  const pdfDoc = await PDFDocument.create();
  const cardW  = pt(POLY_MM.w), cardH = pt(POLY_MM.h);

  const page       = pdfDoc.addPage([cardW, cardH]);
  const imgDataUrl = await plantImageDataUrl(plant);
  const canvas     = await renderPolyCardToCanvas(plant, imgDataUrl);
  const pngBytes   = await canvasToPngBytes(canvas);
  const pngImage   = await pdfDoc.embedPng(pngBytes);

  page.drawImage(pngImage, { x: 0, y: 0, width: cardW, height: cardH });
  downloadPdf(await pdfDoc.save(), `${plant.latinName || 'plant'}-card.pdf`);
}
