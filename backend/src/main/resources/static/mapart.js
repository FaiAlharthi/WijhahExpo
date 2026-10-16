// ===================== خريطة مرسومة (صورة + المسار فوقها) =====================
// الصورة expo-map.png تتمدد على كامل حدود الخريطة (bounds)
// وفوقها نرسم: المسار، دبابيس الأجنحة، البوابات، وأسماء الرحلة
const ART_IMAGE = "expo-map.png";
// ضبط الصورة فوق الممرات: sx/sy = تكبير/تصغير (1 = نفس الحجم)، dx/dy = إزاحة بوحدات الخريطة
const ART_FIT = { sx: 1, sy: 1, dx: 0, dy: 0 };
const ART_ZONE_LABELS = false; // خليها true لو تبين أسماء الزونات فوق الصورة

let artView = null;            // التقريب والسحب: { x, y, w, h }
let artBase = null;            // حدود الخريطة كاملة

// ستايل الحركة (النقاط اللي تمشي على المسار ونبض البداية)
(function () {
    const st = document.createElement("style");
    st.textContent = `
    .art-ants { animation: artAnts 0.9s linear infinite; }
    @keyframes artAnts { to { stroke-dashoffset: -18; } }
    .art-pulse { animation: artPulse 1.6s ease-out infinite; transform-box: fill-box; transform-origin: center; }
    @keyframes artPulse { from { transform: scale(0.6); opacity: .9; } to { transform: scale(2.2); opacity: 0; } }
    .art-pin { cursor: pointer; }
    .art-pin .art-dot { opacity: .55; transition: opacity .15s; }
    .art-pin:hover .art-dot { opacity: 1; stroke: #4fd8ff; stroke-width: 3; }
    .art-lbl { font-family: var(--font-body); font-size: 14px; font-weight: 600; }
  `;
    document.head.appendChild(st);
})();

// شكل الدبوس (قطرة) رأسه عند (x, y)
function pinPath(x, y, s) {
    return `M${x} ${y} C${x - 3 * s} ${y - 6 * s} ${x - 9 * s} ${y - 10 * s} ${x - 9 * s} ${y - 17 * s} A${9 * s} ${9 * s} 0 1 1 ${x + 9 * s} ${y - 17 * s} C${x + 9 * s} ${y - 10 * s} ${x + 3 * s} ${y - 6 * s} ${x} ${y} Z`;
}

// لوحة اسم (مستطيل داكن شفاف وفيه نص)
function artLabel(x, y, text, opts) {
    opts = opts || {};
    const g = el("g", { filter: "url(#artShadow)" });
    const t = el("text", { x, y, "text-anchor": "middle", class: "art-lbl", style: "fill:" + (opts.color || "#ffffff") }, g);
    t.textContent = text;
    let w = text.length * 8 + 20;
    try { w = t.getComputedTextLength() + 20; } catch (e) {}
    const r = el("rect", { x: x - w / 2, y: y - 16, width: w, height: 22, rx: 11, fill: opts.bg || "#101820", opacity: 0.78, stroke: "#ffffff33", "stroke-width": 1 });
    g.insertBefore(r, t);
    return g;
}

function drawArt(start, walk, line, shown) {
    svg.innerHTML = "";
    const b = bounds, W = b.maxX - b.minX, H = b.maxY - b.minY;
    const base = b.minX + "," + b.minY + "," + W + "," + H;
    if (!artView || artBase !== base) { artView = { x: b.minX, y: b.minY, w: W, h: H }; artBase = base; }
    applyArtView();

    // فلاتر: توهج وظل
    el("defs", {}).innerHTML = `
    <filter id="artGlow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <filter id="artShadow" x="-30%" y="-30%" width="160%" height="180%"><feDropShadow dx="0" dy="2" stdDeviation="2.5" flood-opacity="0.35"/></filter>`;

    // 1) الصورة (ولو ما لقاها نحط أرضية ورسالة)
    el("rect", { x: b.minX, y: b.minY, width: W, height: H, fill: "#2a2119" }); // نفس لون أطراف الصورة
    const iw = W * ART_FIT.sx, ih = H * ART_FIT.sy;
    const img = el("image", { href: ART_IMAGE, x: b.minX + (W - iw) / 2 + ART_FIT.dx, y: b.minY + (H - ih) / 2 + ART_FIT.dy, width: iw, height: ih, preserveAspectRatio: "none" });
    img.addEventListener("error", () => { img.remove(); err("حطي صورة الخريطة باسم expo-map.png في مجلد static"); });

    // 2) أسماء الزونات (اختياري)
    if (ART_ZONE_LABELS) zones.forEach(z => artLabel(z.location.x, z.location.y - zoneRadius(z) - 8, z.name));

    // 3) خط مستقيم
    const xy = id => locations[id].x + "," + locations[id].y;
    if (mode !== "dijkstra" && line.legs.length) {
        el("polyline", { points: [start, ...line.legs.map(l => l.to)].map(xy).join(" "), fill: "none", stroke: "#7a5cc4", "stroke-width": 4, "stroke-dasharray": "10 8", "stroke-linecap": "round" });
    }
    // 4) مسار المشي: توهج أزرق + خط أزرق فاتح + نقاط بيضا تمشي
    if (mode !== "straight" && walk.legs.length) {
        const full = [start]; walk.legs.forEach(l => l.route.slice(1).forEach(id => full.push(id)));
        const pts = full.map(xy).join(" ");
        el("polyline", { points: pts, fill: "none", stroke: "#1fa8ff", "stroke-width": 14, "stroke-linejoin": "round", "stroke-linecap": "round", opacity: 0.55, filter: "url(#artGlow)" });
        el("polyline", { points: pts, fill: "none", stroke: "#4fd8ff", "stroke-width": 5, "stroke-linejoin": "round", "stroke-linecap": "round" });
        el("polyline", { points: pts, fill: "none", stroke: "#ffffff", "stroke-width": 2.5, "stroke-dasharray": "1 15", "stroke-linecap": "round", class: "art-ants" });
    }

    // 5) الأجنحة: نقطة صغيرة للكل، ودبوس مرقم لأجنحة الرحلة
    const labels = [];
    pavilions.forEach(pv => {
        const l = locations[pv.location.id]; if (!l) return;
        const idx = shown.findIndex(s => s.to === l.id && !s.exit);
        const on = picked.has(l.id) && l.id !== start;
        const g = el("g", { class: "art-pin", role: "button", "aria-label": pv.name });
        el("title", {}, g).textContent = (flagOf(pv.country) + " " + shortName(pv.name)).trim();
        if (idx >= 0) {
            el("path", { d: pinPath(l.x, l.y, 1.35), fill: "#1e88e5", stroke: "#ffffff", "stroke-width": 2, filter: "url(#artShadow)" }, g);
            el("text", { x: l.x, y: l.y - 18.5, "text-anchor": "middle", "font-size": 14, "font-weight": 800, fill: "#ffffff", "font-family": "var(--font-data)" }, g).textContent = idx + 1;
            labels.push({ x: l.x, y: l.y - 40, text: (flagOf(pv.country) + " " + shortName(pv.name)).trim() });
        } else {
            el("circle", { cx: l.x, cy: l.y, r: on ? 7 : 4.5, fill: on ? "#3fb8a6" : "#ffffff", stroke: on ? "#ffffff" : "#00000066", "stroke-width": 1.5, class: "art-dot", filter: "url(#artShadow)" }, g);
            if (on) labels.push({ x: l.x, y: l.y - 14, text: (flagOf(pv.country) + " " + shortName(pv.name)).trim() });
        }
        g.addEventListener("click", () => togglePav(l.id));
    });

    // 6) البوابات: نقطة واسمها
    entrances.forEach(e => {
        const l = locations[e.location.id]; if (!l) return;
        el("circle", { cx: l.x, cy: l.y, r: 7, fill: "#ffffff", stroke: "#101820", "stroke-width": 3, filter: "url(#artShadow)" });
        artLabel(l.x, l.y - 14, e.name);
    });

    // 7) البداية (نبض أحمر) والخروج (دائرة زرقا منقطة)
    if (locations[start]) {
        const s = locations[start];
        el("circle", { cx: s.x, cy: s.y, r: 12, fill: "none", stroke: "#ff6b6b", "stroke-width": 3, class: "art-pulse" });
        el("circle", { cx: s.x, cy: s.y, r: 14, fill: "none", stroke: "#ff6b6b", "stroke-width": 2.5 });
    }
    const exitLeg = shown.find(s => s.exit);
    if (exitLeg) {
        const x = locations[exitLeg.to];
        el("circle", { cx: x.x, cy: x.y, r: 14, fill: "none", stroke: "#4fd8ff", "stroke-width": 2.5, "stroke-dasharray": "5 4" });
    }

    // 8) أسماء أجنحة الرحلة فوق كل شي
    labels.forEach(t => artLabel(t.x, t.y, t.text));
}

// ---------- تقريب بعجلة الماوس وسحب ----------
function applyArtView() {
    if (artView) svg.setAttribute("viewBox", `${artView.x} ${artView.y} ${artView.w} ${artView.h}`);
}
svg.addEventListener("wheel", e => {
    if (view !== "art" || !artView) return;
    e.preventDefault();
    const r = svg.getBoundingClientRect();
    const mx = artView.x + (e.clientX - r.left) / r.width * artView.w;
    const my = artView.y + (e.clientY - r.top) / r.height * artView.h;
    const k = e.deltaY < 0 ? 0.85 : 1 / 0.85;
    const W = bounds.maxX - bounds.minX;
    const nw = Math.max(W / 6, Math.min(W, artView.w * k)), f = nw / artView.w;
    artView = { x: mx - (mx - artView.x) * f, y: my - (my - artView.y) * f, w: nw, h: artView.h * f };
    applyArtView();
}, { passive: false });
let artDrag = null;
svg.addEventListener("pointerdown", e => { if (view === "art" && !e.target.closest(".art-pin")) artDrag = { x: e.clientX, y: e.clientY, vx: artView.x, vy: artView.y }; });
window.addEventListener("pointermove", e => {
    if (!artDrag) return;
    const k = artView.w / svg.getBoundingClientRect().width;
    artView.x = artDrag.vx - (e.clientX - artDrag.x) * k; artView.y = artDrag.vy - (e.clientY - artDrag.y) * k;
    applyArtView();
});
window.addEventListener("pointerup", () => { artDrag = null; });
svg.addEventListener("dblclick", () => { if (view === "art") { artView = null; render(); } });

window.drawArt = drawArt;