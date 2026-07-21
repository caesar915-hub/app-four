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
return Object.keys(storage.I);
