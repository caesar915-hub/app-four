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
return 'engine loaded';
