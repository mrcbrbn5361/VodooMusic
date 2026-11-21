const { createCanvas, loadImage } = require('@napi-rs/canvas');
const path = require('path');
const fs = require('fs');

/**
 * Vodoo Music — "NOW PLAYING" karti.
 * Tasarim kaynagi: desktop/src/renderer/playerCard.ts (webhook ile ayni gorsel).
 * Webhook (Electron) ve bot (Node) ayri runtime'larda oldugu icin cizim kodu
 * iki yerde durur; palet ve duzen birebir ayni tutulur.
 */

const W = 1200;
const H = 470;
const BG_DEEP = '#050303';
const BG_PANEL = '#190605';
const ACCENT = '#C51D20';
const ACCENT_2 = '#D66A36';
const TEXT = '#E8C6A3';
const BODY = '#B68A65';
const MUTED = '#B68A65';
const FONT = 'Segoe UI, system-ui, sans-serif';

function roundRect(ctx, x, y, w, h, r) {
  const rad = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rad, y);
  ctx.lineTo(x + w - rad, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + rad);
  ctx.lineTo(x + w, y + h - rad);
  ctx.quadraticCurveTo(x + w, y + h, x + w - rad, y + h);
  ctx.lineTo(x + rad, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - rad);
  ctx.lineTo(x, y + rad);
  ctx.quadraticCurveTo(x, y, x + rad, y);
  ctx.closePath();
}

function fitText(ctx, text, maxWidth, maxLines) {
  const words = String(text || '').split(/\s+/).filter(Boolean);
  if (!words.length) return '';
  const lines = [];
  let line = '';
  for (const word of words) {
    const probe = line ? `${line} ${word}` : word;
    if (ctx.measureText(probe).width <= maxWidth) {
      line = probe;
    } else {
      if (line) lines.push(line);
      line = word;
      if (lines.length === maxLines) break;
    }
  }
  if (lines.length < maxLines && line) lines.push(line);
  const out = lines.join('\n');
  const lastLine = out.split('\n').pop();
  if (out !== text && ctx.measureText(lastLine).width > maxWidth) {
    const parts = out.split('\n');
    let tail = parts[parts.length - 1];
    while (tail.length > 1 && ctx.measureText(`${tail}…`).width > maxWidth) tail = tail.slice(0, -1);
    parts[parts.length - 1] = `${tail.trimEnd()}…`;
    return parts.join('\n');
  }
  return out;
}

function formatTime(sec) {
  const s = !isFinite(sec) || sec < 0 ? 0 : Math.floor(sec);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

async function tryLoad(src) {
  if (!src) return null;
  try {
    return await loadImage(src);
  } catch (err) {
    console.warn('[CardRenderer] Görsel yüklenemedi:', err.message);
    return null;
  }
}

function drawCoverFallback(ctx, x, y, size) {
  const g = ctx.createLinearGradient(x, y, x + size, y + size);
  g.addColorStop(0, '#4B090B');
  g.addColorStop(1, '#050303');
  ctx.fillStyle = g;
  roundRect(ctx, x, y, size, size, 18);
  ctx.fill();
  ctx.fillStyle = 'rgba(197,29,32, 0.55)';
  ctx.font = `700 ${Math.round(size * 0.42)}px ${FONT}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('L', x + size / 2, y + size / 2 + 4);
  ctx.textAlign = 'left';
  ctx.textBaseline = 'alphabetic';
}

function drawRoundImage(ctx, img, x, y, size, radius) {
  const scale = Math.max(size / img.width, size / img.height);
  const sw = size / scale;
  const sh = size / scale;
  const sx = (img.width - sw) / 2;
  const sy = (img.height - sh) / 2;
  ctx.save();
  roundRect(ctx, x, y, size, size, radius);
  ctx.clip();
  ctx.drawImage(img, sx, sy, sw, sh, x, y, size, size);
  ctx.restore();
}

async function renderPlayerCard({
  title = 'Bilinmeyen Şarkı',
  artist = 'Bilinmeyen Sanatçı',
  album = 'Vodoo Music',
  coverUrl = null,
  currentSec = 0,
  durationSec = 0,
  username = 'Vodoo Music',
  avatarUrl = null,
  appLabel = 'Vodoo Music'
}) {
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');

  // Zemin
  const bg = ctx.createLinearGradient(0, 0, W, H);
  bg.addColorStop(0, BG_PANEL);
  bg.addColorStop(0.55, BG_DEEP);
  bg.addColorStop(1, '#190605');
  ctx.fillStyle = bg;
  roundRect(ctx, 0, 0, W, H, 22);
  ctx.fill();

  const glowA = ctx.createRadialGradient(180, 120, 10, 180, 120, 620);
  glowA.addColorStop(0, 'rgba(197,29,32, 0.22)');
  glowA.addColorStop(1, 'rgba(197,29,32, 0)');
  ctx.fillStyle = glowA;
  ctx.fillRect(0, 0, W, H);

  const glowB = ctx.createRadialGradient(W - 120, H - 60, 10, W - 120, H - 60, 520);
  glowB.addColorStop(0, 'rgba(139,16,20, 0.20)');
  glowB.addColorStop(1, 'rgba(139,16,20, 0)');
  ctx.fillStyle = glowB;
  ctx.fillRect(0, 0, W, H);

  ctx.strokeStyle = 'rgba(197,29,32, 0.38)';
  ctx.lineWidth = 1.6;
  roundRect(ctx, 0.8, 0.8, W - 1.6, H - 1.6, 21);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(214,106,54, 0.14)';
  ctx.lineWidth = 1;
  roundRect(ctx, 6, 6, W - 12, H - 12, 17);
  ctx.stroke();

  // NOW PLAYING
  ctx.fillStyle = ACCENT;
  roundRect(ctx, 56, 48, 8, 26, 4);
  ctx.fill();
  ctx.font = `700 22px ${FONT}`;
  try { ctx.letterSpacing = '4px'; } catch (e) {}
  ctx.fillText('NOW PLAYING', 78, 68);
  try { ctx.letterSpacing = '0px'; } catch (e) {}

  // Kapak
  const coverSize = 220;
  const coverX = 56;
  const coverY = 96;
  const cover = await tryLoad(coverUrl);
  if (cover) {
    ctx.save();
    ctx.shadowColor = 'rgba(197,29,32, 0.35)';
    ctx.shadowBlur = 28;
    drawRoundImage(ctx, cover, coverX, coverY, coverSize, 18);
    ctx.restore();
  } else {
    const candidates = [
      path.join(__dirname, 'assets', 'vodoo_logo.png'),
      path.join(__dirname, '..', '..', 'desktop', 'assets', 'icon.png'),
      path.join(__dirname, '..', '..', 'desktop', 'assets', 'logo.png')
    ];
    let seal = null;
    for (const p of candidates) {
      if (fs.existsSync(p)) {
        seal = await tryLoad(p);
        if (seal) break;
      }
    }
    if (seal) {
      ctx.save();
      roundRect(ctx, coverX, coverY, coverSize, coverSize, 18);
      ctx.clip();
      ctx.drawImage(seal, coverX, coverY, coverSize, coverSize);
      ctx.restore();
    } else {
      drawCoverFallback(ctx, coverX, coverY, coverSize);
    }
  }
  ctx.strokeStyle = 'rgba(197,29,32, 0.45)';
  ctx.lineWidth = 1.4;
  roundRect(ctx, coverX + 0.5, coverY + 0.5, coverSize - 1, coverSize - 1, 18);
  ctx.stroke();

  // Metin kolonu
  const textX = coverX + coverSize + 64;
  const maxTextWidth = W - textX - 56;

  ctx.fillStyle = TEXT;
  ctx.font = `700 46px ${FONT}`;
  const titleText = fitText(ctx, title, maxTextWidth, 2);
  ctx.fillText(titleText, textX, 150);

  const titleBottom = titleText.includes('\n') ? 196 : 172;
  ctx.fillStyle = BODY;
  ctx.font = `500 30px ${FONT}`;
  ctx.fillText(fitText(ctx, artist, maxTextWidth, 1), textX, titleBottom + 34);

  ctx.fillStyle = MUTED;
  ctx.font = `400 24px ${FONT}`;
  ctx.fillText(fitText(ctx, album || 'Vodoo Music', maxTextWidth, 1), textX, titleBottom + 68);

  // İlerleme çubuğu
  const barX = 56;
  const barW = W - 112;
  const barY = 356;
  const barH = 10;

  ctx.fillStyle = 'rgba(232,198,163, 0.08)';
  roundRect(ctx, barX, barY, barW, barH, barH / 2);
  ctx.fill();

  const dur = Math.max(0, durationSec || 0);
  const ratio = dur > 0 ? Math.min(1, Math.max(0, (currentSec || 0) / dur)) : 0;
  if (ratio > 0) {
    const fillW = Math.max(barH, barW * ratio);
    const fillGrad = ctx.createLinearGradient(barX, 0, barX + fillW, 0);
    fillGrad.addColorStop(0, ACCENT_2);
    fillGrad.addColorStop(1, ACCENT);
    ctx.save();
    ctx.shadowColor = 'rgba(197,29,32, 0.55)';
    ctx.shadowBlur = 14;
    ctx.fillStyle = fillGrad;
    roundRect(ctx, barX, barY, fillW, barH, barH / 2);
    ctx.fill();
    ctx.restore();

    ctx.save();
    ctx.shadowColor = 'rgba(197,29,32, 0.9)';
    ctx.shadowBlur = 18;
    ctx.fillStyle = ACCENT;
    ctx.beginPath();
    ctx.arc(barX + fillW, barY + barH / 2, 9, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  ctx.font = `500 22px ${FONT}`;
  ctx.fillStyle = BODY;
  ctx.textAlign = 'left';
  ctx.fillText(formatTime(currentSec || 0), barX, barY + 40);
  ctx.textAlign = 'right';
  ctx.fillStyle = MUTED;
  ctx.fillText(formatTime(dur), barX + barW, barY + 40);
  ctx.textAlign = 'left';

  // Ayırıcı + footer
  const lineY = 424;
  ctx.strokeStyle = 'rgba(214,106,54, 0.18)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(56, lineY);
  ctx.lineTo(W - 56, lineY);
  ctx.stroke();

  const avatarSize = 30;
  const avatarY = lineY + 14;
  const avatar = await tryLoad(avatarUrl);
  if (avatar) {
    ctx.save();
    ctx.beginPath();
    ctx.arc(56 + avatarSize / 2, avatarY + avatarSize / 2, avatarSize / 2, 0, Math.PI * 2);
    ctx.clip();
    ctx.drawImage(avatar, 56, avatarY, avatarSize, avatarSize);
    ctx.restore();
  }

  ctx.fillStyle = TEXT;
  ctx.font = `600 20px ${FONT}`;
  ctx.fillText(fitText(ctx, username || 'Vodoo Music', 520, 1), 56 + avatarSize + 14, avatarY + 22);

  ctx.textAlign = 'right';
  ctx.fillStyle = MUTED;
  ctx.font = `500 18px ${FONT}`;
  ctx.fillText(appLabel || 'Vodoo Music', W - 56, avatarY + 22);
  ctx.textAlign = 'left';

  return canvas.toBuffer('image/png');
}

module.exports = { renderPlayerCard };
