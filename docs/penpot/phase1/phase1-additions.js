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
