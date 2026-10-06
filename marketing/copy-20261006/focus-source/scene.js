/*
 * UniEnter "FOCUS" (v3) — one protagonist shape, one phrase at a time. 1080×1920.
 * Enter key → input field (one newline) → ⌘ docks → the message leaves as a bubble,
 * the ↵ stays and becomes the app icon.
 * Every frame is a pure function of t (seconds). Driver: render.mjs → window.__render(t).
 */
"use strict";

const W = 1080, H = 1920, FPS = 30, DURATION = 12.0;
const C = {
  bg: "#F4F1EA", ink: "#1C1B19", ink2: "#6E6B64", line: "#D9D3C7",
  card: "#FFFFFF", field: "#FAF8F3", teal: "#0F8F82", cream: "#F4F1EA",
};
const JP = '"Hiragino Sans"';
const EN = '"SF Pro Display", "Helvetica Neue", system-ui, sans-serif';

/* ───────── math / motion ───────── */
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, u) => a + (b - a) * u;
const prog = (t, a, b) => clamp((t - a) / (b - a));
const outExpo = (u) => (u >= 1 ? 1 : 1 - Math.pow(2, -10 * u));
const inCubic = (u) => u * u * u;
const inOutCubic = (u) => (u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2);
const outCubic = (u) => 1 - Math.pow(1 - u, 3);
const outQuint = (u) => 1 - Math.pow(1 - u, 5);
// damped spring step response (analytic, deterministic)
function spring(tau, w, z) {
  if (tau <= 0) return 0;
  const wd = w * Math.sqrt(1 - z * z);
  return 1 - Math.exp(-z * w * tau) * (Math.cos(wd * tau) + ((z * w) / wd) * Math.sin(wd * tau));
}
/* motion vocabulary: three kinds, not one spring for everything
 *  sharp  – decisive move, no overshoot (expo out)
 *  land   – fast approach with a small overshoot that settles (≈4%)
 *  linger – slow tail, for things that drift into place */
function M(t, t0, d, kind = "sharp") {
  if (t <= t0) return 0;
  if (kind === "sharp") return outExpo(prog(t, t0, t0 + d));
  if (kind === "land") return spring(t - t0, 7.2 / d, 0.68);
  if (kind === "linger") return outQuint(prog(t, t0, t0 + d));
  if (kind === "glide") return inOutCubic(prog(t, t0, t0 + d));
  if (kind === "in") return inCubic(prog(t, t0, t0 + d));
  return prog(t, t0, t0 + d);
}
const R = (x, y, w, h, r) => ({ x, y, w, h, r });
const lr = (a, b, u) => R(lerp(a.x, b.x, u), lerp(a.y, b.y, u), lerp(a.w, b.w, u), lerp(a.h, b.h, u), lerp(a.r, b.r, u));
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const mix = (a, b, u) => {
  const A = hex(a), B = hex(b);
  u = clamp(u);
  return `rgb(${Math.round(lerp(A[0], B[0], u))},${Math.round(lerp(A[1], B[1], u))},${Math.round(lerp(A[2], B[2], u))})`;
};
// key press: quick dip, springy release
function press(t, at) {
  const d = t - at;
  if (d < 0) return 1;
  if (d < 0.07) return 1 - 0.075 * outCubic(d / 0.07);
  return 1 - 0.075 * (1 - spring(d - 0.07, 26, 0.55));
}

/* ───────── drawing primitives ───────── */
let ctx;
function rrect(r, fill, stroke, lw = 2) {
  const rad = Math.max(0, Math.min(r.r, r.w / 2, r.h / 2));
  ctx.beginPath();
  ctx.roundRect(r.x, r.y, Math.max(0, r.w), Math.max(0, r.h), rad);
  if (fill) { ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.stroke(); }
}
// bubble: rounded with a tighter bottom-right corner (sent message)
function bubbleShape(r, fill, tail = 1) {
  const big = Math.min(r.r, r.w / 2, r.h / 2), small = lerp(big, Math.min(10, big), tail);
  ctx.beginPath();
  ctx.roundRect(r.x, r.y, r.w, r.h, [big, big, small, big]);
  ctx.fillStyle = fill;
  ctx.fill();
}
function softShadow(r, depth) {
  if (depth <= 0) return;
  ctx.save();
  ctx.shadowColor = `rgba(28,27,25,${0.10 + 0.10 * clamp(depth)})`;
  ctx.shadowBlur = 18 + 50 * depth;
  ctx.shadowOffsetY = 6 + 22 * depth;
  rrect(r, "rgba(0,0,0,1)");
  ctx.restore();
}
function scaled(r, s, ox = 0.5, oy = 0.5) {
  const cx = r.x + r.w * ox, cy = r.y + r.h * oy;
  return R(cx - (r.w * s) * ox, cy - (r.h * s) * oy, r.w * s, r.h * s, r.r * s);
}
function font(size, weight = 600, fam = JP) { return `${weight} ${size}px ${fam}`; }
function text(s, x, y, size, color, weight = 600, fam = JP, align = "left") {
  ctx.font = font(size, weight, fam);
  ctx.fillStyle = color;
  ctx.textAlign = align;
  ctx.textBaseline = "middle";
  ctx.fillText(s, x, y);
}
function measure(s, size, weight = 600, fam = JP) {
  ctx.font = font(size, weight, fam);
  return ctx.measureText(s).width;
}
// ↵ with the exact app-icon geometry (1024 box, square side 824). s = icon-square size it belongs to.
function retGlyph(cx, cy, s, color, wMul = 1) {
  const k = s / 824;
  const P = (x, y) => [cx + (x - 512) * k, cy + (y - 511) * k];
  ctx.strokeStyle = color;
  ctx.lineWidth = 78 * k * wMul;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.beginPath();
  ctx.moveTo(...P(679, 370)); ctx.lineTo(...P(679, 550)); ctx.lineTo(...P(345, 550));
  ctx.moveTo(...P(448, 447)); ctx.lineTo(...P(345, 550)); ctx.lineTo(...P(448, 653));
  ctx.stroke();
}
const RET_W = (s) => (412 * s) / 824; // drawn width of the glyph
function ring(r, t, at, color = C.teal) {
  const u = prog(t, at, at + 0.42);
  if (u <= 0 || u >= 1) return;
  const g = 6 + 26 * outCubic(u);
  ctx.globalAlpha *= 1 - u;
  rrect(R(r.x - g, r.y - g, r.w + 2 * g, r.h + 2 * g, r.r + g), null, color, 6 * (1 - u) + 2);
  ctx.globalAlpha /= Math.max(1e-3, 1 - u);
}
function withAlpha(a, fn) {
  if (a <= 0.001) return;
  const p = ctx.globalAlpha;
  ctx.globalAlpha = p * clamp(a);
  fn();
  ctx.globalAlpha = p;
}

/* ───────── keys ───────── */
function enterKeyFace(r, labelAlpha, fs) {
  // label "Enter" only; the ↵ is drawn separately (it is the thread through the film)
  withAlpha(labelAlpha, () => {
    const tw = measure("Enter", fs, 600, EN);
    text("Enter", r.x + r.w / 2 - (tw + fs * 0.9) / 2, r.y + r.h / 2 + fs * 0.03, fs, C.cream, 600, EN);
  });
}

/* ───────── layout ───────── */
const COPY_Y = 620;                                  // the one copy slot
const KEY0 = R(240, 860, 600, 320, 64);              // opening Enter key
const KEY_FS = 120;
const FIELD_X = 110, FIELD_W = 860, FIELD_TOP = 920, FIELD_R = 44;
const LINE1 = 100, LINE_GAP = 110;                   // line centres inside the field
const fieldH = (n) => 200 + LINE_GAP * (n - 1);
const GLYPH_X = 884;                                 // ↵ sits on the field's right edge zone
const BAR_X = 170;
const BAR1 = [[170, 330], [352, 520], [542, 650]];   // "words" of line 1 (no letters)
const BAR2 = [[170, 300], [322, 470]];
const CMD0 = R(-220, 1155, 130, 130, 30);
const CMD_DOCK = R(64, 1155, 130, 130, 30);          // straddles the field's bottom-left corner
const ICON = R(370, 740, 340, 340, 340 * 0.225);

/* ───────── timeline (12.0s) ───────── */
const T = {
  copy1Out: 1.6,
  morph: 1.85, labelOut: 1.85, type1: [2.12, 2.42],
  copy2In: 2.5, nl: 2.78, trace: [2.8, 3.12], grow: 2.86, type2: [3.12, 3.45], copy2Out: 4.3,
  cmdIn: [4.6, 4.95], copy3In: 5.08, copy3Out: 6.15,
  pressSend: 6.42, morphB: 6.46, fly: 6.8,
  toCenter: 7.45, iconOpen: 7.6,
  lock: 8.45,
};
const MOTION = [[1.6, 2.5], [2.5, 3.6], [4.3, 5.4], [6.1, 8.0], [8.0, 9.2]];

function glyphPosKey(r, fs) {
  const tw = measure("Enter", fs, 600, EN);
  const x0 = r.x + r.w / 2 - (tw + fs * 0.9) / 2;
  return { x: x0 + tw + fs * 0.62, y: r.y + r.h / 2, s: fs * 1.75 };
}

/* the one copy slot: a phrase enters only after the previous one has fully left */
function copy(t, segs, inAt, outAt, fs = 80, yOffset = 0) {
  const ui = inAt <= 0 ? 1 : M(t, inAt, 0.4, "sharp");
  const uo = outAt == null ? 0 : M(t, outAt, 0.28, "in");
  if (ui <= 0 || uo >= 1) return;
  const full = segs.map((s) => s[0]).join("");
  const w = measure(full, fs, 800);
  let x = 540 - w / 2;
  const y = COPY_Y + yOffset + 30 * (1 - ui) - 40 * uo;
  withAlpha(ui * (1 - uo), () => {
    for (const [s, col] of segs) {
      text(s, x, y, fs, col, 800);
      x += measure(s, fs, 800);
    }
  });
}

function bars(rx, ry, list, upto, color, scale = 1) {
  // upto: progress 0..1 across the whole line
  const total = list[list.length - 1][1] - list[0][0];
  const reach = list[0][0] + total * upto;
  ctx.fillStyle = color;
  for (const [a, b] of list) {
    if (reach <= a) break;
    const e = Math.min(b, reach);
    const h = 30 * scale;
    ctx.beginPath();
    ctx.roundRect(rx + (a - FIELD_X) * scale, ry - h / 2, (e - a) * scale, h, h / 2);
    ctx.fill();
  }
  return list[0][0] + total * upto;
}

/* ───────── frame ───────── */
function frame(t) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.fillStyle = C.bg;
  ctx.fillRect(0, 0, W, H);

  /* copy slot — one phrase at a time */
  copy(t, [["Enterでの", C.ink]], 0, T.copy1Out, 80, -50);
  copy(t, [["うっかり送信を防ぐ", C.ink]], 0, T.copy1Out, 80, 50);
  copy(t, [["Enterは", C.ink], ["改行", C.teal], ["。", C.ink]], T.copy2In, T.copy2Out);
  copy(t, [["⌘Enterで", C.ink], ["送信", C.teal], ["。", C.ink]], T.copy3In, T.copy3Out);

  /* protagonist: key → field → bubble */
  const m = M(t, T.morph, 0.62, "land");
  const g1 = M(t, T.grow, 0.45, "land");
  const nLines = 1 + g1;
  const field = R(FIELD_X, FIELD_TOP, FIELD_W, fieldH(nLines), FIELD_R);
  let body = lr(KEY0, field, m);
  const fillU = clamp(m * 1.3);
  // send: frame morphs into a big sent bubble in place, then leaves upward (the only exit)
  const mb = M(t, T.morphB, 0.32, "land");
  const BUB = R(140, 940, 620, 270, 54);   // contracts left, away from the ↵ on the frame edge
  const isBub = t >= T.morphB ? clamp(mb * 1.5) : 0;
  if (t >= T.morphB) body = lr(field, BUB, mb);
  const fl = M(t, T.fly, 0.5, "in");
  if (t >= T.fly) {
    const u = clamp(fl);
    body = R(body.x + 70 * Math.sin(Math.PI * u) - 40 * u, body.y - 1500 * u, body.w * (1 - 0.25 * u), body.h * (1 - 0.25 * u), body.r);
  }
  if (body.y + body.h > -50) {
    const moving = (t > T.morph && t < T.morph + 0.45) || (t > T.morphB && t < T.fly + 0.5) || (t > T.grow && t < T.grow + 0.3);
    softShadow(body, moving ? 0.55 : 0.14);
    if (isBub >= 1) bubbleShape(body, C.ink);
    else if (isBub > 0) rrect(body, mix(C.card, C.ink, isBub), mix(C.line, C.ink, isBub), 2);
    else {
      rrect(body, mix(C.ink, C.card, fillU), null);
      withAlpha(fillU, () => rrect(body, null, C.line, 2));
    }
    // key label, only while it is a key
    if (t < T.morph + 0.3) enterKeyFace(body, 1 - prog(t, T.labelOut, T.labelOut + 0.16), KEY_FS * (body.h / KEY0.h) ** 0.5);
    // text bars (no letters)
    const bcol = mix(C.ink, C.cream, isBub);
    const sx = body.w / (t >= T.morphB ? lerp(FIELD_W, BUB.w, 0) : FIELD_W);
    void sx;
    if (t >= T.type1[0]) {
      ctx.save();
      ctx.beginPath(); ctx.rect(body.x, body.y, body.w, body.h); ctx.clip();
      const k = t >= T.morphB ? body.w / FIELD_W : 1;
      const pad = t >= T.morphB ? lerp(0, -10, isBub) : 0;
      const y1 = body.y + LINE1 * (t >= T.morphB ? body.h / fieldH(2) : 1);
      const y2 = y1 + LINE_GAP * (t >= T.morphB ? body.h / fieldH(2) : 1);
      const e1 = bars(body.x + (BAR_X - FIELD_X) * k + pad, y1, BAR1, prog(t, ...T.type1), bcol, k);
      let e2 = null;
      if (t >= T.type2[0]) e2 = bars(body.x + (BAR_X - FIELD_X) * k + pad, y2, BAR2, prog(t, ...T.type2), bcol, k);
      ctx.restore();
      // caret (field only)
      if (isBub === 0 && t < T.pressSend) {
        const onLine2 = t >= T.trace[1];
        const cx = onLine2 ? (e2 ?? BAR_X) + 10 : e1 + 10;
        const blinkOn = (t > T.type2[1] + 0.2) ? Math.floor((t - T.type2[1]) / 0.42) % 2 === 0 : true;
        if (blinkOn && !(t > T.nl && t < T.trace[1])) {
          ctx.fillStyle = C.teal;
          ctx.fillRect(cx, (onLine2 ? y2 : y1) - 30, 5, 60);
        }
      }
    }
    // the newline trace: ↵ path from end of line 1, down, back to the start of line 2
    const tu = prog(t, T.trace[0], T.trace[1]);
    const tf = 1 - prog(t, T.trace[1] + 0.04, T.trace[1] + 0.2); // clear right after landing, before line 2 grows under it
    if (tu > 0 && tf > 0 && t < T.morphB) {
      const y1 = body.y + LINE1, y2 = y1 + LINE_GAP;
      const xR = BAR1[2][1] + 22, xL = BAR_X - 14;
      const L1 = y2 - y1, L2 = xR - xL;
      const d = outCubic(tu) * (L1 + L2);
      withAlpha(tf, () => {
        ctx.strokeStyle = C.teal; ctx.lineWidth = 9; ctx.lineCap = "round"; ctx.lineJoin = "round";
        ctx.beginPath();
        ctx.moveTo(xR, y1);
        if (d <= L1) ctx.lineTo(xR, y1 + d);
        else { ctx.lineTo(xR, y2); ctx.lineTo(xR - (d - L1), y2); }
        ctx.stroke();
        if (tu >= 1) {
          ctx.beginPath();
          ctx.moveTo(xL + 18, y2 - 16); ctx.lineTo(xL, y2); ctx.lineTo(xL + 18, y2 + 16);
          ctx.stroke();
        }
      });
    }
  }

  /* ⌘: docks onto the field's bottom-left corner (same object, not a separate panel) */
  if (t >= T.cmdIn[0] - 0.01) {
    const ci = M(t, T.cmdIn[0], T.cmdIn[1] - T.cmdIn[0], "in");
    let rc = lr(CMD0, CMD_DOCK, ci);
    const sn = t - T.cmdIn[1];
    let sq = 1;
    if (sn > 0 && sn < 0.3) sq = 1 - 0.09 * Math.exp(-sn * 16) * Math.cos(sn * 40);
    rc = R(rc.x, rc.y + (rc.h * (1 - sq)) / 2, rc.w, rc.h * sq, rc.r);
    rc = scaled(rc, press(t, T.pressSend));
    // after send its job is done: it shrinks away into its corner
    const out = M(t, T.fly + 0.05, 0.3, "in");
    rc = scaled(rc, 1 - out);
    if (rc.w > 1) {
      rrect(rc, C.ink);
      text("⌘", rc.x + rc.w / 2, rc.y + rc.h / 2 + 2, 74 * (rc.w / 130), C.cream, 500, JP, "center");
      ring(rc, t, T.cmdIn[1]);
      ring(rc, t, T.pressSend);
    }
  }

  /* ↵ — the thread: key glyph → field control → stays when the message leaves → becomes the icon */
  drawGlyph(t, body);

  /* lockup */
  const items = [
    [(y) => text("UniEnter", 540, y, 124, C.ink, 700, EN, "center"), 1216],
    [(y) => text("Mac用・14日間無料", 540, y, 50, C.ink2, 600, JP, "center"), 1352],
    [(y) => text("unienter.oc-to.com", 540, y, 44, C.ink2, 600, EN, "center"), 1420],
  ];
  items.forEach(([fn, y], i) => {
    const u = M(t, T.lock + i * 0.13, 0.42, "sharp");
    if (u > 0) withAlpha(u, () => fn(y + 30 * (1 - u)));
  });
}

function drawGlyph(t, body) {
  const k0 = glyphPosKey(KEY0, KEY_FS);
  const m = M(t, T.morph, 0.62, "land");
  const g1 = M(t, T.grow, 0.45, "land");
  // field control position: right edge, on the current (last) line
  const fy = FIELD_TOP + LINE1 + LINE_GAP * g1;
  const fieldPos = { x: GLYPH_X, y: fy, s: 150 };
  let p = { x: lerp(k0.x, fieldPos.x, m), y: lerp(k0.y, fieldPos.y, m), s: lerp(k0.s, fieldPos.s, m) };
  if (t < T.morph) p = k0;
  // send: hand-off — the ↵ is set onto the frame's fixed point (right edge) and stays as the message leaves
  // then, after ~0.2s of emptiness, it moves to centre and the icon opens behind it
  const c = M(t, T.toCenter, 0.6, "land");
  const center = { x: ICON.x + ICON.w / 2, y: ICON.y + ICON.h / 2, s: ICON.w };
  if (t >= T.toCenter) p = { x: lerp(p.x, center.x, c), y: lerp(p.y, center.y, c), s: lerp(p.s, center.s, c) };
  // icon body opens from the glyph's centre
  const io = M(t, T.iconOpen, 0.62, "land");
  if (t >= T.iconOpen) {
    const s = clamp(io, 0, 1.08);
    const cx = p.x, cy = p.y;
    const r = R(cx - (ICON.w * s) / 2, cy - (ICON.h * s) / 2, ICON.w * s, ICON.h * s, ICON.r * s);
    softShadow(r, t < T.iconOpen + 0.5 ? 0.4 : 0.12);
    rrect(r, C.teal);
    ring(ICON, t, T.iconOpen + 0.55);
  }
  const col = mix(C.teal, C.cream, prog(t, T.iconOpen, T.iconOpen + 0.3));
  // press accents
  let s = p.s;
  const pop = t > T.fly + 0.2 && t < T.toCenter + 0.1 ? Math.sin(Math.PI * prog(t, T.fly + 0.2, T.toCenter + 0.1)) : 0;
  s *= 1 + 0.35 * pop * (t < T.toCenter ? 1 : 0) + 0.35 * (t >= T.toCenter ? 0 : 0);
  s *= Math.min(press(t, T.nl - 0.04), press(t, T.pressSend));
  retGlyph(p.x, p.y, s, col, t < T.toCenter ? 0.9 : lerp(0.9, 1, c));
  if (t < T.morphB) ring(R(p.x - 46, p.y - 40, 92, 80, 24), t, T.nl - 0.04);
  ring(R(p.x - 46, p.y - 40, 92, 80, 24), t, T.pressSend);
}

/* ───────── render loop (motion blur by subframe accumulation) ───────── */
const canvas = document.getElementById("film");
const out = canvas.getContext("2d");
const work = document.createElement("canvas");
work.width = W; work.height = H;
ctx = work.getContext("2d");

async function init() {
  await Promise.all([
    document.fonts.load(font(80, 800), "Enterでのうっかり送信を防ぐは改行⌘で送信"),
    document.fonts.load(font(74, 500), "⌘"),
    document.fonts.load(font(50, 600), "Mac用・14日間無料"),
    document.fonts.load(font(124, 700, EN), "UniEnter"),
    document.fonts.load(font(120, 600, EN), "Enter"),
  ]);
  return { duration: DURATION, fps: FPS };
}
function render(t) {
  const moving = MOTION.some(([a, b]) => t > a && t < b);
  const N = moving ? 10 : 1;
  const shutter = 0.5 / FPS;
  out.globalCompositeOperation = "source-over";
  for (let i = 0; i < N; i++) {
    const ts = N === 1 ? t : t - shutter / 2 + ((i + 0.5) / N) * shutter;
    frame(ts);
    out.globalAlpha = 1 / (i + 1);
    out.drawImage(work, 0, 0);
  }
  out.globalAlpha = 1;
  return Promise.resolve({ subframes: N });
}
window.__init = init;
window.__render = render;
window.__grab = (type = "image/png") => canvas.toDataURL(type, 0.93);

const q = new URLSearchParams(location.search);
if (q.has("t")) {
  if (q.has("preview")) document.body.classList.add("preview");
  init().then(() => render(parseFloat(q.get("t"))));
}
