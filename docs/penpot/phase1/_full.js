// Squirl Penpot build engine — paste into execute_code in chunks. Defines storage.C / storage.U / storage.G.
// CHUNK A: colors + low-level helpers ------------------------------------------------
storage.C = {
  bg:'#F6F1E7', card:'#FCF8EF', surface2:'#EFE8D8', ink:'#221E16', muted:'#7A7361',
  hair:'#E3DAC7', accent:'#B8842A', green:'#5F8A4C', amber:'#E0A33A', danger:'#B5503A',
  med:'#7E5CA8', warn:'#C2772E', sleep:'#5566A6', onFill:'#1C1C1E', elevated:'#FCF8EF',
  moodBase:['#DA7A2A','#EDA94A','#9FCB79','#5FB36E','#2E8B57'],
  moodWord:['#8E470F','#8A5600','#41691F','#2C6B3B','#1E5C38'],
  energy:['#7C6E2E','#A89236','#D2BB40','#EEDA4C','#FCEE64'],
  focus:['#44546E','#4E6F94','#5889BA','#63A4E0','#79C4FF'],
};
storage.U = {
  _font(name){ const a = penpot.fonts.all; const arr = Array.isArray(a) ? a : a(); return arr.find(f=>f.name===name)||null; },
  inter(){ return storage.U._fi || (storage.U._fi = storage.U._font('Inter')); },
  mono(){ return storage.U._fm || (storage.U._fm = storage.U._font('Roboto Mono')); },
  add(parent, sh){ parent.insertChild(parent.children.length, sh); return sh; },
  text(parent, str, o){
    o = o || {};
    const up = o.upper ? String(str).toUpperCase() : String(str);
    const t = penpot.createText(up);
    const f = o.mono ? storage.U.mono() : storage.U.inter();
    if (f){ const w = String(o.weight||400); const v = f.variants.find(v=>v.fontWeight===w) || f.variants.find(v=>v.fontWeight==='400'); f.applyToText(t, v); }
    t.fontSize = o.size||16;
    if (o.width){ t.resize(o.width, t.height||20); t.growType='auto-height'; t.align = o.align||'left'; }
    else { t.growType='auto-width'; }
    if (o.track) t.letterSpacing = o.track;
    if (o.lh) t.lineHeight = o.lh;
    t.fills = [{ fillColor:(o.color||storage.C.ink), fillOpacity:(o.op==null?1:o.op) }];
    t.x = o.x||0; t.y = o.y||0;
    return storage.U.add(parent, t);
  },
  rect(parent, o){
    const s = penpot.createRectangle(); s.resize(o.w, o.h); s.x=o.x; s.y=o.y;
    if (o.r) s.borderRadius = o.r;
    if (o.rtl!=null){ s.borderRadiusTopLeft=o.rtl; s.borderRadiusTopRight=o.rtr; s.borderRadiusBottomRight=o.rbr; s.borderRadiusBottomLeft=o.rbl; }
    if (o.grad) s.fills=[{ fillColorGradient:o.grad, fillOpacity:1 }];
    else if (o.fill) s.fills=[{ fillColor:o.fill, fillOpacity:(o.fillOp==null?1:o.fillOp) }];
    else s.fills=[];
    if (o.stroke) s.strokes=[{ strokeColor:o.stroke, strokeWidth:(o.sw==null?1:o.sw), strokeAlignment:(o.align||'inner'), strokeStyle:(o.dash?'dashed':'solid') }];
    if (o.shadow) s.shadows=[{ style:'drop-shadow', offsetX:0, offsetY:3, blur:10, spread:0, color:{ color:'#221E16', opacity:0.06 } }];
    return storage.U.add(parent, s);
  },
  ellipse(parent, o){
    const e = penpot.createEllipse(); e.resize(o.d, o.d); e.x=o.x; e.y=o.y;
    if (o.fill) e.fills=[{ fillColor:o.fill, fillOpacity:(o.fillOp==null?1:o.fillOp) }]; else e.fills=[];
    if (o.stroke) e.strokes=[{ strokeColor:o.stroke, strokeWidth:(o.sw==null?1:o.sw), strokeAlignment:(o.salign||'center'), strokeStyle:(o.dash?'dashed':'solid') }];
    return storage.U.add(parent, e);
  },
  card(parent, o){ return storage.U.rect(parent, { x:o.x, y:o.y, w:o.w, h:o.h, r:(o.r==null?16:o.r), fill:(o.fill||storage.C.card), stroke:(o.noStroke?null:storage.C.hair), sw:1, align:'inner', shadow:(o.noShadow?false:true) }); },
  meadow(w,h){ return { type:'linear', startX:0, startY:0, endX:1, endY:1, width:1, stops:[{color:storage.C.green, offset:0, opacity:1},{color:storage.C.amber, offset:1, opacity:1}] }; },
};
// CHUNK B: glyph SVG generators -------------------------------------------------------
storage.G = {
  hex(c, op){ return op==null ? `${c}` : `${c}`; },
  // sprout (mood) — design 24x26, scales with lift, butt/miter
  sprout(level, size, color){
    const lift = 0.66 + level*0.068; const s = Math.min(size/24, size/26)*lift;
    const ox = (size-24*s)/2, oy = (size-26*s)/2;
    const P = (x,y)=>`${(x*s+ox).toFixed(2)} ${(y*s+oy).toFixed(2)}`;
    const open = level>=4, top = open?9:11, fill = Math.min(1, 0.42+level*0.145);
    let d=''; const W=(w)=>(w*s).toFixed(2);
    let g = `<path d="M ${P(12,25)} C ${P(12,18)} ${P(12,14)} ${P(12,top)}" fill="none" stroke="${color}" stroke-opacity="0.6" stroke-width="${W(1.5)}" stroke-linecap="butt" stroke-linejoin="miter"/>`;
    g += `<path d="M ${P(12,top)} C ${P(open?4:6,open?13:14)} ${P(open?5:6,open?2:5)} ${P(12,1)} C ${P(open?19:18,open?2:5)} ${P(open?20:18,open?13:14)} ${P(12,top)} Z" fill="${color}" fill-opacity="${fill.toFixed(3)}" stroke="${color}" stroke-width="${W(1.3)}" stroke-linejoin="miter"/>`;
    if (level>=3) g += `<path d="M ${P(12,top)} L ${P(12,4)}" fill="none" stroke="${color}" stroke-opacity="0.5" stroke-width="${W(1)}"/>`;
    if (level>=5){ const cx=(12*s+ox).toFixed(2), cy=(6*s+oy).toFixed(2), r=(2*s).toFixed(2); g += `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${color}"/>`; }
    return { svg:`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${g}</svg>`, dash:false };
  },
  // bolt (energy) — design 24x26, scales with lift, round join
  bolt(level, size, color){
    const lift = 0.6 + level*0.08; const s = Math.min(size/24, size/26)*lift;
    const ox=(size-24*s)/2, oy=(size-26*s)/2; const P=(x,y)=>`${(x*s+ox).toFixed(2)} ${(y*s+oy).toFixed(2)}`;
    const fill = Math.min(1, 0.35+level*0.15); const sw=((0.9+level*0.16)*s).toFixed(2);
    const d = `M ${P(14,2)} L ${P(6,15)} L ${P(11,15)} L ${P(9.5,24)} L ${P(19,11)} L ${P(13,11)} Z`;
    const g = `<path d="${d}" fill="${color}" fill-opacity="${fill.toFixed(3)}" stroke="${color}" stroke-width="${sw}" stroke-linejoin="round" stroke-linecap="butt"/>`;
    return { svg:`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${g}</svg>`, dash:false };
  },
  // aperture (focus) — design 24x26, NO lift, center (12,13). outer dashed at L<=2 (post-process)
  aperture(level, size, color){
    const s = Math.min(size/24, size/26); const ox=(size-24*s)/2, oy=(size-26*s)/2;
    const cx=(12*s+ox), cy=(13*s+oy); const C=(r)=>`cx="${cx.toFixed(2)}" cy="${cy.toFixed(2)}" r="${(r*s).toFixed(2)}"`;
    let g=''; // order: outer -> mid -> inner -> core(last)
    g += `<circle ${C(9)} fill="none" stroke="${color}" stroke-opacity="${(0.3+level*0.12).toFixed(3)}" stroke-width="${(1.2*s).toFixed(2)}"${level<=2?' stroke-dasharray="'+(3*s).toFixed(2)+' '+(3*s).toFixed(2)+'"':''}/>`;
    if (level>=2) g += `<circle ${C(6)} fill="none" stroke="${color}" stroke-opacity="${(0.4+level*0.11).toFixed(3)}" stroke-width="${(1.3*s).toFixed(2)}"/>`;
    if (level>=4) g += `<circle ${C(3.3)} fill="none" stroke="${color}" stroke-opacity="0.92" stroke-width="${(1.4*s).toFixed(2)}"/>`;
    if (level>=3){ const r=(level-1)*0.85; g += `<circle ${C(r)} fill="${color}" fill-opacity="${(0.5+level*0.1).toFixed(3)}"/>`; }
    return { svg:`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${g}</svg>`, dash:(level<=2) };
  },
  // bed (sleep) — design 24x24, static, round cap+join
  bed(size, color){
    color = color || storage.C.sleep; const s = size/24; const ox=(size-24*s)/2, oy=(size-24*s)/2;
    const P=(x,y)=>`${(x*s+ox).toFixed(2)} ${(y*s+oy).toFixed(2)}`; const W=(w)=>(w*s).toFixed(2);
    let g = `<path d="M ${P(3,18)} L ${P(3,12)} Q ${P(3,10)} ${P(5,10)} L ${P(14,10)} Q ${P(18,10)} ${P(18,14)} L ${P(18,18)}" fill="none" stroke="${color}" stroke-width="${W(1.7)}" stroke-linecap="round" stroke-linejoin="round"/>`;
    g += `<path d="M ${P(3,14)} L ${P(20,14)}" fill="none" stroke="${color}" stroke-width="${W(1.7)}" stroke-linecap="round"/>`;
    g += `<rect x="${(6.2*s+ox).toFixed(2)}" y="${(8.4*s+oy).toFixed(2)}" width="${(4.6*s).toFixed(2)}" height="${(1.6*s).toFixed(2)}" rx="${(0.8*s).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.4)}" stroke-linejoin="round"/>`;
    return { svg:`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${g}</svg>`, dash:false };
  },
  // capsule (medication) — static; literal stroke widths (not design-scaled)
  capsule(size, color){
    color = color || storage.C.med; const capW=0.86*size, capH=0.42*size; const left=(size-capW)/2, top=(size-capH)/2, r=capH/2;
    const rx=left, ry=left+capW/2; const t=top, bo=top+capH;
    let g = `<rect x="${left.toFixed(2)}" y="${top.toFixed(2)}" width="${capW.toFixed(2)}" height="${capH.toFixed(2)}" rx="${r.toFixed(2)}" fill="${color}" fill-opacity="0.22"/>`;
    g += `<path d="M ${ry.toFixed(2)} ${t.toFixed(2)} L ${(rx+r).toFixed(2)} ${t.toFixed(2)} A ${r.toFixed(2)} ${r.toFixed(2)} 0 0 0 ${rx.toFixed(2)} ${(t+r).toFixed(2)} L ${rx.toFixed(2)} ${(bo-r).toFixed(2)} A ${r.toFixed(2)} ${r.toFixed(2)} 0 0 0 ${(rx+r).toFixed(2)} ${bo.toFixed(2)} L ${ry.toFixed(2)} ${bo.toFixed(2)} Z" fill="${color}" fill-opacity="0.5"/>`;
    g += `<rect x="${left.toFixed(2)}" y="${top.toFixed(2)}" width="${capW.toFixed(2)}" height="${capH.toFixed(2)}" rx="${r.toFixed(2)}" fill="none" stroke="${color}" stroke-width="2"/>`;
    g += `<rect x="${(size/2-0.8).toFixed(2)}" y="${(size/2-capH*0.33).toFixed(2)}" width="1.6" height="${(capH*0.66).toFixed(2)}" fill="${color}" fill-opacity="0.8"/>`;
    return { svg:`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${g}</svg>`, dash:false };
  },
  // carryover arc (medication ring): progress 0..1, drawn in a size x size frame, diameter d
  arc(size, d, progress, color, sw){
    color = color||storage.C.med; sw = sw||3.3; const r=d/2; const cx=size/2, cy=size/2;
    const sx=cx, sy=cy-r; const ang=2*Math.PI*Math.min(0.999, Math.max(0.001, progress));
    const ex=cx+r*Math.sin(ang), ey=cy-r*Math.cos(ang); const large = progress>0.5?1:0;
    const path = `M ${sx.toFixed(2)} ${sy.toFixed(2)} A ${r.toFixed(2)} ${r.toFixed(2)} 0 ${large} 1 ${ex.toFixed(2)} ${ey.toFixed(2)}`;
    const g = `<path d="${path}" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round"/>`;
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${g}</svg>`;
  },
  // place a generated glyph; handles aperture dashed post-process
  place(parent, gen, x, y){
    const g = penpot.createShapeFromSvg(gen.svg);
    if (!g) return null;
    g.x = x; g.y = y;
    if (gen.dash){ // outer ring = children[1] (children[0] is bounding rect)
      const ch = g.children||[]; const ring = ch[1];
      if (ring && ring.strokes && ring.strokes[0]){ const s0=ring.strokes[0]; ring.strokes=[{ strokeColor:s0.strokeColor, strokeWidth:s0.strokeWidth, strokeOpacity:s0.strokeOpacity, strokeStyle:'dashed', strokeAlignment:'center' }]; }
    }
    parent.insertChild(parent.children.length, g);
    return g;
  },
  // svg string -> placed group (for owner SF SVGs / arcs)
  svg(parent, svgString, x, y){ const g = penpot.createShapeFromSvg(svgString); if(!g) return null; g.x=x; g.y=y; parent.insertChild(parent.children.length, g); return g; },
  // glyph dispatch by signal kind + level
  signal(parent, kind, level, size, x, y){
    let gen; const C = storage.C;
    if (kind==='mood') gen = storage.G.sprout(level, size, C.moodBase[level-1]);
    else if (kind==='energy') gen = storage.G.bolt(level, size, C.energy[level-1]);
    else if (kind==='focus') gen = storage.G.aperture(level, size, C.focus[level-1]);
    else if (kind==='sleep') gen = storage.G.bed(size, C.sleep);
    else if (kind==='medication') gen = storage.G.capsule(size, C.med);
    return storage.G.place(parent, gen, x, y);
  },
  chevron(dir, size, color, w){
    w = w||1.6; const k=size; let pts;
    if (dir==='down') pts=[[0.2,0.34],[0.5,0.64],[0.8,0.34]];
    else if (dir==='up') pts=[[0.2,0.64],[0.5,0.34],[0.8,0.64]];
    else if (dir==='right') pts=[[0.36,0.2],[0.66,0.5],[0.36,0.8]];
    else pts=[[0.64,0.2],[0.34,0.5],[0.64,0.8]];
    const d = `M ${(pts[0][0]*k).toFixed(2)} ${(pts[0][1]*k).toFixed(2)} L ${(pts[1][0]*k).toFixed(2)} ${(pts[1][1]*k).toFixed(2)} L ${(pts[2][0]*k).toFixed(2)} ${(pts[2][1]*k).toFixed(2)}`;
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${k}" height="${k}" viewBox="0 0 ${k} ${k}"><path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  },
};
// CHUNK C: board composition helpers --------------------------------------------------
storage.B = {
  aw(str, size){ return String(str).length * size * 0.56; },
  // SF capsule.righthalf.filled STAND-IN (swap for owner SVG): outline + filled right half
  medPill(size, color){
    const w=size, h=size*0.5, top=(size-h)/2, r=h/2;
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">`
      + `<rect x="0.5" y="${top.toFixed(2)}" width="${(w-1).toFixed(2)}" height="${h.toFixed(2)}" rx="${r.toFixed(2)}" fill="none" stroke="${color}" stroke-width="1"/>`
      + `<path d="M ${(w/2).toFixed(2)} ${top.toFixed(2)} L ${(w-r).toFixed(2)} ${top.toFixed(2)} A ${r.toFixed(2)} ${r.toFixed(2)} 0 0 1 ${(w-r).toFixed(2)} ${(top+h).toFixed(2)} L ${(w/2).toFixed(2)} ${(top+h).toFixed(2)} Z" fill="${color}"/></svg>`;
  },
  foldedCard(parent, o){
    const C = storage.C; const x=o.x, y=o.y, w=o.w, h=o.h;
    storage.U.rect(parent, { x, y, w, h, r:16, fill:C.card });
    if (o.tint) storage.U.rect(parent, { x, y, w, h, r:16, fill:o.tint, fillOp:0.24 });
    const empty = !!o.emptyText;
    const moodX = x+16, textX = (o.moodLevel? x+68 : x+16);
    if (o.moodLevel) storage.G.signal(parent, 'mood', o.moodLevel, 40, moodX, y+(h-40)/2);
    const titleY = empty ? y+12 : y + (h/2) - 17;
    let tStr = o.titleWord ? (o.titleWord + ' · ' + o.titleRest) : o.titleRest;
    const t = storage.U.text(parent, tStr, { x:textX, y:titleY, size:16, weight:600, color:C.ink });
    if (o.titleWord){
      const wlen=o.titleWord.length; const r1=t.getRange(0, wlen); r1.fills=[{fillColor:o.titleWordColor, fillOpacity:1}];
      const r2=t.getRange(wlen, wlen+3); r2.fills=[{fillColor:C.muted, fillOpacity:1}];
    }
    const sumY = titleY + 23;
    if (empty){ storage.U.text(parent, o.emptyText, { x:textX, y:sumY, size:15, color:C.muted, width:w-32 }); }
    else {
      let cx = textX;
      for (const it of o.summary){
        if (it.kind==='med'){ storage.G.svg(parent, storage.B.medPill(15, C.med), cx, sumY+1); }
        else storage.G.signal(parent, it.kind, it.level, 15, cx, sumY);
        cx += 17;
        storage.U.text(parent, it.label, { x:cx, y:sumY+1, size:12, color:C.muted });
        cx += storage.B.aw(it.label, 12) + 12;
      }
    }
    if (!empty) storage.G.svg(parent, storage.G.chevron('down', 14, C.muted, 1.6), x+w-26, y+(h-14)/2);
    return { x, y, w, h };
  },
};

// storage.I — hand-drawn SF-Symbol-equivalent icons. Authored in 24x24 space, baked to target size.
storage.I = {
  _wrap(size, inner){ return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${inner}</svg>`; },
  _p(k){ return (x,y)=>`${(x*k).toFixed(2)} ${(y*k).toFixed(2)}`; },
  heart(size, color){ const k=size/24, P=storage.I._p(k);
    return storage.I._wrap(size, `<path d="M ${P(12,20.7)} C ${P(4.8,15)} ${P(2,11.2)} ${P(2,7.6)} C ${P(2,4.8)} ${P(4.2,3)} ${P(6.5,3)} C ${P(8.7,3)} ${P(11,4.6)} ${P(12,6.7)} C ${P(13,4.6)} ${P(15.3,3)} ${P(17.5,3)} C ${P(19.8,3)} ${P(22,4.8)} ${P(22,7.6)} C ${P(22,11.2)} ${P(19.2,15)} ${P(12,20.7)} Z" fill="${color}"/>`); },
  zzz(size, color){ const k=size/24, P=storage.I._p(k); const W=(w)=>(w*k).toFixed(2);
    const z=(xl,xr,yt,yb,w)=>`<path d="M ${P(xl,yt)} L ${P(xr,yt)} L ${P(xl,yb)} L ${P(xr,yb)}" fill="none" stroke="${color}" stroke-width="${W(w)}" stroke-linecap="round" stroke-linejoin="round"/>`;
    return storage.I._wrap(size, z(3,9,15.5,20.5,1.7)+z(10,15,9.5,13.5,1.5)+z(16,20,4,7,1.3)); },
  thermometer(size, color){ const k=size/24, P=storage.I._p(k); const W=(w)=>(w*k).toFixed(2);
    let g = `<rect x="${(10*k).toFixed(2)}" y="${(3*k).toFixed(2)}" width="${(4*k).toFixed(2)}" height="${(14*k).toFixed(2)}" rx="${(2*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.4)}"/>`;
    g += `<rect x="${(11.1*k).toFixed(2)}" y="${(10*k).toFixed(2)}" width="${(1.8*k).toFixed(2)}" height="${(8*k).toFixed(2)}" fill="${color}"/>`;
    g += `<circle cx="${(12*k).toFixed(2)}" cy="${(18.5*k).toFixed(2)}" r="${(3.6*k).toFixed(2)}" fill="${color}"/>`;
    for (const yy of [6,9,12]) g += `<path d="M ${P(14.3,yy)} L ${P(16,yy)}" stroke="${color}" stroke-width="${W(1.1)}" stroke-linecap="round"/>`;
    return storage.I._wrap(size, g); },
  bandage(size, color){ const k=size/24;
    const inner = `<g transform="rotate(45 ${(12*k).toFixed(2)} ${(12*k).toFixed(2)})">`
      + `<rect x="${(3*k).toFixed(2)}" y="${(8.5*k).toFixed(2)}" width="${(18*k).toFixed(2)}" height="${(7*k).toFixed(2)}" rx="${(3.5*k).toFixed(2)}" fill="${color}"/>`
      + `<rect x="${(8.5*k).toFixed(2)}" y="${(8.5*k).toFixed(2)}" width="${(7*k).toFixed(2)}" height="${(7*k).toFixed(2)}" fill="${color}" fill-opacity="0.55"/>`
      + [[10.3,10.3],[13.7,10.3],[10.3,13.7],[13.7,13.7]].map(p=>`<circle cx="${(p[0]*k).toFixed(2)}" cy="${(p[1]*k).toFixed(2)}" r="${(0.7*k).toFixed(2)}" fill="#FCF8EF"/>`).join('')
      + `</g>`;
    return storage.I._wrap(size, inner); },
  calendar(size, color){ const k=size/24, P=storage.I._p(k); const W=(w)=>(w*k).toFixed(2);
    let g = `<rect x="${(3.5*k).toFixed(2)}" y="${(5*k).toFixed(2)}" width="${(17*k).toFixed(2)}" height="${(16*k).toFixed(2)}" rx="${(3*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.6)}"/>`;
    g += `<path d="M ${P(3.5,9.5)} L ${P(20.5,9.5)}" stroke="${color}" stroke-width="${W(1.5)}"/>`;
    g += `<path d="M ${P(8,3)} L ${P(8,6.5)}" stroke="${color}" stroke-width="${W(1.6)}" stroke-linecap="round"/>`;
    g += `<path d="M ${P(16,3)} L ${P(16,6.5)}" stroke="${color}" stroke-width="${W(1.6)}" stroke-linecap="round"/>`;
    for (const p of [[8,13.5],[12,13.5],[16,13.5],[8,17],[12,17]]) g += `<circle cx="${(p[0]*k).toFixed(2)}" cy="${(p[1]*k).toFixed(2)}" r="${(1*k).toFixed(2)}" fill="${color}"/>`;
    return storage.I._wrap(size, g); },
  checkCircle(size, color){ const k=size/24, P=storage.I._p(k); const W=(w)=>(w*k).toFixed(2);
    let g = `<circle cx="${(12*k).toFixed(2)}" cy="${(12*k).toFixed(2)}" r="${(9*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.6)}"/>`;
    g += `<path d="M ${P(7.8,12.3)} L ${P(10.8,15.2)} L ${P(16.2,8.8)}" fill="none" stroke="${color}" stroke-width="${W(1.8)}" stroke-linecap="round" stroke-linejoin="round"/>`;
    return storage.I._wrap(size, g); },
  chartBar(size, color){ const k=size/24;
    const bar=(x,y,w,h)=>`<rect x="${(x*k).toFixed(2)}" y="${(y*k).toFixed(2)}" width="${(w*k).toFixed(2)}" height="${(h*k).toFixed(2)}" rx="${(1*k).toFixed(2)}" fill="${color}"/>`;
    return storage.I._wrap(size, bar(4,13,3.8,7)+bar(10.1,8.5,3.8,11.5)+bar(16.2,4.5,3.8,15.5)); },
  gear(size, color){ const k=size/24; const cx=12*k, cy=12*k; const teeth=8, n=teeth*2, Rt=10*k, Rv=7.4*k;
    let pts=[]; for (let i=0;i<n;i++){ const a=(Math.PI*2*i/n)-Math.PI/2; const r=(i%2===0)?Rt:Rv; pts.push([cx+r*Math.cos(a), cy+r*Math.sin(a)]); }
    let d='M '+pts.map(p=>`${p[0].toFixed(2)} ${p[1].toFixed(2)}`).join(' L ')+' Z';
    let g = `<path d="${d}" fill="none" stroke="${color}" stroke-width="${(1.5*k).toFixed(2)}" stroke-linejoin="round"/>`;
    g += `<circle cx="${cx.toFixed(2)}" cy="${cy.toFixed(2)}" r="${(3.6*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${(1.5*k).toFixed(2)}"/>`;
    return storage.I._wrap(size, g); },
  pencil(size, color){ const k=size/24, P=storage.I._p(k); const W=(w)=>(w*k).toFixed(2);
    let g = `<path d="M ${P(15.5,4.5)} L ${P(19.5,8.5)} L ${P(9,19)} L ${P(4.5,20)} L ${P(5.5,15.5)} Z" fill="none" stroke="${color}" stroke-width="${W(1.5)}" stroke-linejoin="round"/>`;
    g += `<path d="M ${P(13.5,6.5)} L ${P(17.5,10.5)}" stroke="${color}" stroke-width="${W(1.3)}"/>`;
    return storage.I._wrap(size, g); },
  xmark(size, color){ const k=size/24, P=storage.I._p(k); const W=(w)=>(w*k).toFixed(2);
    return storage.I._wrap(size, `<path d="M ${P(6,6)} L ${P(18,18)} M ${P(18,6)} L ${P(6,18)}" stroke="${color}" stroke-width="${W(1.8)}" stroke-linecap="round"/>`); },
  play(size, color){ const k=size/24, P=storage.I._p(k);
    return storage.I._wrap(size, `<path d="M ${P(8,5)} L ${P(19,12)} L ${P(8,19)} Z" fill="${color}"/>`); },
  pause(size, color){ const k=size/24;
    const b=(x)=>`<rect x="${(x*k).toFixed(2)}" y="${(5*k).toFixed(2)}" width="${(3.2*k).toFixed(2)}" height="${(14*k).toFixed(2)}" rx="${(1*k).toFixed(2)}" fill="${color}"/>`;
    return storage.I._wrap(size, b(7.4)+b(13.4)); },
  ellipsis(size, color){ const k=size/24;
    const d=(cx)=>`<circle cx="${(cx*k).toFixed(2)}" cy="${(12*k).toFixed(2)}" r="${(1.7*k).toFixed(2)}" fill="${color}"/>`;
    return storage.I._wrap(size, d(6)+d(12)+d(18)); },
};

// Phase 1 additions — runs AFTER engine.js + icons.js. References storage.* (C,U,G,B,I).
// No top-level return (concatenates cleanly for eval/new Function injection).

// --- CrescentRing hero (angular-gradient approximation, 40 arc segments) ---
storage.G.crescent = function(size, lw){
  lw = lw||22; const cx=size/2, cy=size/2, r=(size-lw)/2;
  const g1=[0x5F,0x8A,0x4C], g2=[0xE0,0xA3,0x3A];
  const hex=(a)=>'#'+a.map(v=>('0'+Math.round(v).toString(16)).slice(-2)).join('');
  const lerp=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
  const colAt=(loc)=> loc<=0.5 ? hex(lerp(g1,g2,loc/0.5)) : hex(lerp(g2,g1,(loc-0.5)/0.5));
  const N=40; let g=''; const pt=(a)=>{ const rad=a*Math.PI/180; return [(cx+r*Math.sin(rad)).toFixed(2),(cy-r*Math.cos(rad)).toFixed(2)]; };
  for(let i=0;i<N;i++){ const a0=(i/N)*360, a1=((i+1)/N)*360+0.7; const p0=pt(a0),p1=pt(a1), loc=(i+0.5)/N;
    g+=`<path d="M ${p0[0]} ${p0[1]} A ${r.toFixed(2)} ${r.toFixed(2)} 0 0 1 ${p1[0]} ${p1[1]}" fill="none" stroke="${colAt(loc)}" stroke-width="${lw}" stroke-linecap="butt"/>`; }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${g}</svg>`;
};

// --- RecordingRow (Day Detail) ---
storage.B.recRow = function(b, x, y, w, o){
  const C=storage.C;
  storage.U.card(b, {x, y, w, h:o.h});
  storage.U.ellipse(b, {x:x+12, y:y+18, d:10, fill:o.dot});
  const tx = x+34;
  storage.U.text(b, o.title, {x:tx, y:y+13, size:16, weight:600, color:C.ink});
  if (o.done) storage.G.svg(b, storage.I.checkCircle(17, C.green), x+w-12-17, y+14);
  storage.U.text(b, o.meta, {x:tx, y:y+37, size:12, color:C.muted});
  if (o.tags){
    let cx=tx; const ty=y+58;
    o.tags.forEach(tg=>{
      const lw=storage.B.aw(tg.label,12), cw=8+14+4+lw+8;
      storage.U.rect(b, {x:cx, y:ty, w:cw, h:22, r:11, fill:tg.color, fillOp:0.14});
      if (tg.kind) storage.G.signal(b, tg.kind, tg.level, 14, cx+8, ty+4);
      storage.U.text(b, tg.label, {x:cx+8+14+4, y:ty+5, size:12, color:C.ink, op:0.85});
      cx += cw + 6;
    });
  }
  return y+o.h;
};

// --- DoseTrack medication bar ---
storage.B.medBar = function(b, x, y, w){
  const C=storage.C;
  storage.U.card(b, {x, y, w, h:84});
  storage.G.signal(b, 'medication', null, 18, x+14, y+14);
  storage.U.text(b, 'Concerta 36 mg', {x:x+40, y:y+15, size:14, weight:600, color:C.ink});
  storage.U.text(b, 'active', {x:x+w-14-storage.B.aw('active',13), y:y+16, size:13, color:C.med});
  storage.U.rect(b, {x:x+14, y:y+44, w:w-28, h:8, r:4, fill:C.surface2});
  storage.U.rect(b, {x:x+14, y:y+44, w:(w-28)*0.55, h:8, r:4, fill:C.med});
  storage.U.text(b, 'taken 09:15', {x:x+14, y:y+58, size:12, color:C.muted, mono:true});
  return y+84;
};

// --- iOS toggle (on/off) ---
storage.B.toggle = function(b, x, y, on){
  const C=storage.C, w=51, h=31;
  storage.U.rect(b, {x, y, w, h, r:16, fill:(on?C.green:'#C9C2B0')});
  storage.U.ellipse(b, {x:(on?x+w-2-27:x+2), y:y+2, d:27, fill:'#FFFFFF'});
  return x+w;
};

// --- Settings list helpers ---
storage.B.setRow = function(b, x, y, w, o){
  const C=storage.C; const h=o.h||50; let lx=x+14;
  if (o.icon){ storage.G.svg(b, o.icon, x+14, y+(h-20)/2); lx=x+14+20+12; }
  storage.U.text(b, o.label, {x:lx, y:y+(h-19)/2, size:16, color:(o.labelColor||C.ink), weight:(o.weight||400)});
  if (o.toggle!=null) storage.B.toggle(b, x+w-14-51, y+(h-31)/2, o.toggle);
  else if (o.value){ const vw=storage.B.aw(o.value,16), cw=o.chevron?16:0;
    storage.U.text(b, o.value, {x:x+w-14-vw-cw, y:y+(h-19)/2, size:16, color:C.muted});
    if(o.chevron) storage.G.svg(b, storage.G.chevron('right',13,C.muted,1.6), x+w-14-13, y+(h-13)/2); }
  else if (o.chevron) storage.G.svg(b, storage.G.chevron('right',13,C.muted,1.6), x+w-14-13, y+(h-13)/2);
  return y+h;
};
storage.B.sep = function(b, x, y, w){ storage.U.rect(b, {x:x+50, y, w:w-64, h:1, fill:storage.C.hair}); };
storage.B.secHead = function(b, x, y, text){ storage.U.text(b, text, {x:x+16, y, size:13, color:storage.C.muted}); return y+22; };

// --- SF-Symbol-equivalent icons (24x24 design space baked to size) ---
storage.I.waveform=(size,color)=>{ const k=size/24; const bar=(x,h)=>`<rect x="${((x-1)*k).toFixed(2)}" y="${((12-h/2)*k).toFixed(2)}" width="${(2*k).toFixed(2)}" height="${(h*k).toFixed(2)}" rx="${k.toFixed(2)}" fill="${color}"/>`;
  return storage.I._wrap(size, bar(5,8)+bar(9,16)+bar(12,22)+bar(15,11)+bar(19,17)); };
storage.I.clock=(size,color)=>{ const k=size/24, p=storage.I._p(k), W=(w)=>(w*k).toFixed(2);
  let g=`<circle cx="${(12*k).toFixed(2)}" cy="${(12*k).toFixed(2)}" r="${(9*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.6)}"/>`;
  g+=`<path d="M ${p(12,12)} L ${p(12,7.5)}" stroke="${color}" stroke-width="${W(1.5)}" stroke-linecap="round"/>`;
  g+=`<path d="M ${p(12,12)} L ${p(15.5,13.5)}" stroke="${color}" stroke-width="${W(1.5)}" stroke-linecap="round"/>`;
  return storage.I._wrap(size, g); };
storage.I.trash=(size,color)=>{ const k=size/24, p=storage.I._p(k), W=(w)=>(w*k).toFixed(2);
  let g=`<path d="M ${p(4.5,6.5)} L ${p(19.5,6.5)}" stroke="${color}" stroke-width="${W(1.6)}" stroke-linecap="round"/>`;
  g+=`<path d="M ${p(9,6.5)} L ${p(9,4.2)} Q ${p(9,3)} ${p(10.2,3)} L ${p(13.8,3)} Q ${p(15,3)} ${p(15,4.2)} L ${p(15,6.5)}" fill="none" stroke="${color}" stroke-width="${W(1.4)}" stroke-linejoin="round"/>`;
  g+=`<path d="M ${p(6.2,6.5)} L ${p(7.2,19.8)} Q ${p(7.3,21)} ${p(8.5,21)} L ${p(15.5,21)} Q ${p(16.7,21)} ${p(16.8,19.8)} L ${p(17.8,6.5)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}" stroke-linejoin="round"/>`;
  g+=`<path d="M ${p(10,10)} L ${p(10.2,17)}" stroke="${color}" stroke-width="${W(1.3)}" stroke-linecap="round"/><path d="M ${p(14,10)} L ${p(13.8,17)}" stroke="${color}" stroke-width="${W(1.3)}" stroke-linecap="round"/>`;
  return storage.I._wrap(size, g); };
storage.I.checkmark=(size,color)=>{ const k=size/24, p=storage.I._p(k), W=(w)=>(w*k).toFixed(2);
  return storage.I._wrap(size, `<path d="M ${p(5,12.8)} L ${p(10,17.5)} L ${p(19,7)}" fill="none" stroke="${color}" stroke-width="${W(2)}" stroke-linecap="round" stroke-linejoin="round"/>`); };
storage.I.antenna=(size,color)=>{ const k=size/24, W=(w)=>(w*k).toFixed(2); const cx=12,cy=12;
  const dot=`<circle cx="${(cx*k).toFixed(2)}" cy="${(cy*k).toFixed(2)}" r="${(1.7*k).toFixed(2)}" fill="${color}"/>`;
  const arc=(r,dir)=>{ const X=(cx+dir*r*0.7), Y0=cy-r*0.7, Y1=cy+r*0.7, sweep=dir>0?1:0;
    return `<path d="M ${(X*k).toFixed(2)} ${(Y0*k).toFixed(2)} A ${(r*k).toFixed(2)} ${(r*k).toFixed(2)} 0 0 ${sweep} ${(X*k).toFixed(2)} ${(Y1*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.4)}" stroke-linecap="round"/>`; };
  return storage.I._wrap(size, dot+arc(4.5,1)+arc(8.5,1)+arc(4.5,-1)+arc(8.5,-1)); };
storage.I.clockArrow=(size,color)=>{ const k=size/24, p=storage.I._p(k), W=(w)=>(w*k).toFixed(2);
  let g=`<path d="M ${p(20.3,12)} A ${(8.3*k).toFixed(2)} ${(8.3*k).toFixed(2)} 0 1 1 ${p(16,5.2)}" fill="none" stroke="${color}" stroke-width="${W(1.6)}" stroke-linecap="round"/>`;
  g+=`<path d="M ${p(16.2,2.3)} L ${p(16.5,5.6)} L ${p(13.2,5.4)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}" stroke-linecap="round" stroke-linejoin="round"/>`;
  g+=`<path d="M ${p(12,12)} L ${p(12,8.2)}" stroke="${color}" stroke-width="${W(1.4)}" stroke-linecap="round"/><path d="M ${p(12,12)} L ${p(14.8,13.4)}" stroke="${color}" stroke-width="${W(1.4)}" stroke-linecap="round"/>`;
  return storage.I._wrap(size, g); };
storage.I.pillsCircle=(size,color)=>{ const k=size/24, p=storage.I._p(k), W=(w)=>(w*k).toFixed(2); const c=(12*k).toFixed(2);
  let g=`<circle cx="${c}" cy="${c}" r="${(9.5*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}"/>`;
  g+=`<g transform="rotate(45 ${c} ${c})"><rect x="${(7.5*k).toFixed(2)}" y="${(10.3*k).toFixed(2)}" width="${(9*k).toFixed(2)}" height="${(3.4*k).toFixed(2)}" rx="${(1.7*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.3)}"/><path d="M ${p(12,10.3)} L ${p(12,13.7)}" stroke="${color}" stroke-width="${W(1.3)}"/></g>`;
  return storage.I._wrap(size, g); };
storage.I.pill=(size,color)=>{ const k=size/24, p=storage.I._p(k), W=(w)=>(w*k).toFixed(2); const c=(12*k).toFixed(2);
  let g=`<g transform="rotate(45 ${c} ${c})"><rect x="${(4.5*k).toFixed(2)}" y="${(9.3*k).toFixed(2)}" width="${(15*k).toFixed(2)}" height="${(5.4*k).toFixed(2)}" rx="${(2.7*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}"/><path d="M ${p(12,9.3)} L ${p(12,14.7)}" stroke="${color}" stroke-width="${W(1.4)}"/></g>`;
  return storage.I._wrap(size, g); };
storage.I.rectStack=(size,color)=>{ const k=size/24, W=(w)=>(w*k).toFixed(2);
  let g=`<rect x="${(6.5*k).toFixed(2)}" y="${(4.5*k).toFixed(2)}" width="${(12*k).toFixed(2)}" height="${(4*k).toFixed(2)}" rx="${(1.8*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.4)}" stroke-opacity="0.55"/>`;
  g+=`<rect x="${(4*k).toFixed(2)}" y="${(8*k).toFixed(2)}" width="${(16*k).toFixed(2)}" height="${(12*k).toFixed(2)}" rx="${(2.5*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.6)}"/>`;
  return storage.I._wrap(size, g); };
storage.I.rectExpand=(size,color)=>{ const k=size/24, P=storage.I._p(k), W=(w)=>(w*k).toFixed(2);
  let g=`<rect x="${(4*k).toFixed(2)}" y="${(5*k).toFixed(2)}" width="${(16*k).toFixed(2)}" height="${(14*k).toFixed(2)}" rx="${(2.5*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.6)}"/>`;
  g+=`<path d="M ${P(9.5,10)} L ${P(12,7.5)} L ${P(14.5,10)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}" stroke-linecap="round" stroke-linejoin="round"/>`;
  g+=`<path d="M ${P(9.5,14)} L ${P(12,16.5)} L ${P(14.5,14)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}" stroke-linecap="round" stroke-linejoin="round"/>`;
  return storage.I._wrap(size, g); };
storage.I.lockDoc=(size,color)=>{ const k=size/24, P=storage.I._p(k), W=(w)=>(w*k).toFixed(2);
  let g=`<rect x="${(5*k).toFixed(2)}" y="${(3*k).toFixed(2)}" width="${(14*k).toFixed(2)}" height="${(18*k).toFixed(2)}" rx="${(2.2*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}"/>`;
  g+=`<rect x="${(9*k).toFixed(2)}" y="${(12.2*k).toFixed(2)}" width="${(6*k).toFixed(2)}" height="${(5*k).toFixed(2)}" rx="${(1*k).toFixed(2)}" fill="${color}"/>`;
  g+=`<path d="M ${P(10,12.2)} L ${P(10,10.6)} Q ${P(10,9)} ${P(12,9)} Q ${P(14,9)} ${P(14,10.6)} L ${P(14,12.2)}" fill="none" stroke="${color}" stroke-width="${W(1.2)}"/>`;
  return storage.I._wrap(size, g); };
storage.I.docOnDoc=(size,color)=>{ const k=size/24, W=(w)=>(w*k).toFixed(2);
  let g=`<rect x="${(8*k).toFixed(2)}" y="${(3*k).toFixed(2)}" width="${(12*k).toFixed(2)}" height="${(15*k).toFixed(2)}" rx="${(2*k).toFixed(2)}" fill="none" stroke="${color}" stroke-width="${W(1.5)}" stroke-opacity="0.5"/>`;
  g+=`<rect x="${(4*k).toFixed(2)}" y="${(6*k).toFixed(2)}" width="${(12*k).toFixed(2)}" height="${(15*k).toFixed(2)}" rx="${(2*k).toFixed(2)}" fill="#FCF8EF" stroke="${color}" stroke-width="${W(1.5)}"/>`;
  return storage.I._wrap(size, g); };
