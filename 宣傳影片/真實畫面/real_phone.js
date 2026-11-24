// 宣傳影片的「真實畫面」模式：把 video.html 裡手刻的手機畫面換成真實 App 截圖。
// 開法：render.py --real（設 window.__REAL__），或瀏覽器開 video.html?real&t=秒數 預覽。
// 截圖與時間軸來自 timeline_video.js（compose.py 產生），時間軸和旁白段落對齊。
// 手機的進場、退場位置照抄原本 #phone 每一幀的 transform／opacity，章節字卡、字幕、片尾卡都不動。
(() => {
  const q = new URLSearchParams(location.search);
  if (!(window.__REAL__ || q.has('real')) || !window.REAL_TL) return;
  const T = window.REAL_TL, TRANS = .45, TAP = .45;

  const css = document.createElement('style');
  css.textContent = `
  #phone,#sb,#island,.scr,.co,#s5-ladder{visibility:hidden !important}
  /* 真實手機：原生尺寸 426×928（螢幕 394×896＝狀態列 44＋App 852），縮成和原本手機差不多大 */
  #rwrap{position:absolute;left:1200px;top:58px;width:426px;height:928px;z-index:4;transform-origin:50% 50%}
  #rphone{position:absolute;inset:0;transform:scale(.94);transform-origin:0 0}
  #rframe{position:absolute;inset:0;border-radius:62px;background:#15181B;box-shadow:0 40px 80px rgba(34,49,63,.25),0 0 0 2px #2B3036 inset}
  #rscreen{position:absolute;left:16px;top:16px;width:394px;height:896px;border-radius:47px;overflow:hidden;background:#fff}
  #rbar{position:absolute;left:0;top:0;width:100%;height:44px;z-index:5;display:flex;align-items:center;justify-content:space-between;
    padding:4px 30px 0;font:700 15px "Segoe UI",sans-serif;color:#22313F}
  #rbar.light{color:#fff}
  #rbar .icons{display:flex;gap:5px;align-items:center}
  #rbar .icons i{display:block;width:3px;background:currentColor;border-radius:1px}
  #rbar .batt{width:24px;height:11px;border:1.5px solid currentColor;border-radius:3px;padding:1px;opacity:.9}
  #rbar .batt b{display:block;height:100%;width:80%;background:currentColor;border-radius:1px}
  #risland{position:absolute;left:50%;top:10px;width:118px;height:32px;margin-left:-59px;border-radius:18px;background:#000;z-index:6}
  .rshot{position:absolute;left:0;top:44px;width:394px;height:852px;display:none}
  .rshot img{width:100%;height:100%;display:block}
  .rshot::after{content:'';position:absolute;inset:0;background:#000;opacity:var(--dim,0);pointer-events:none}
  #rtap{position:absolute;width:46px;height:46px;margin:-23px 0 0 -23px;border-radius:50%;background:rgba(255,255,255,.55);
    border:3px solid rgba(34,49,63,.45);z-index:8;opacity:0;pointer-events:none}`;
  document.head.appendChild(css);

  const wrap = document.createElement('div');
  wrap.id = 'rwrap';
  wrap.innerHTML = `<div id="rphone"><div id="rframe"></div><div id="rscreen">
    <div id="rbar"><span>9:41</span><span class="icons"><i style="height:5px"></i><i style="height:7px"></i><i style="height:9px"></i><i style="height:11px"></i><span class="batt"><b></b></span></span></div>
    <div id="risland"></div><div id="rshots"></div><div id="rtap"></div></div></div>`;
  document.getElementById('stage').appendChild(wrap);
  const host = wrap.querySelector('#rshots'), bar = wrap.querySelector('#rbar'), tap = wrap.querySelector('#rtap');
  const els = T.map(it => {
    const d = document.createElement('div'); d.className = 'rshot';
    const img = document.createElement('img'); img.src = it.src; d.appendChild(img); host.appendChild(d); return d;
  });
  window.READY = Promise.all([...host.querySelectorAll('img')].map(i => i.decode().catch(() => {})));

  const ease = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  const clamp = x => Math.max(0, Math.min(1, x));
  const place = (el, x, y, o, dim) => {
    el.style.display = 'block'; el.style.transform = `translate(${x}px,${y}px)`;
    el.style.opacity = o; el.style.setProperty('--dim', dim || 0);
    el.style.boxShadow = 'none';
  };
  const end = T[T.length - 1].t + T[T.length - 1].dur;

  function realSeek(t) {
    // 跟著原本手機動：位置、透明度
    const ph = document.getElementById('phone');
    wrap.style.opacity = ph.style.opacity === '' ? 1 : ph.style.opacity;
    wrap.style.transform = ph.style.transform || '';
    els.forEach(e => e.style.display = 'none');
    t = Math.min(t, end - 1e-3);
    let i = T.findIndex(it => t < it.t + it.dur);
    if (i < 0) i = T.length - 1;
    const cur = T[i], prev = T[i - 1], local = t - cur.t;
    const p = prev && cur.trans !== 'none' ? ease(clamp(local / TRANS)) : 1;
    const W = 394, H = 852;
    if (p < 1) {
      const a = els[i - 1], b = els[i];
      switch (cur.trans) {
        case 'push': place(a, -W * .3 * p, 0, 1, .25 * p); place(b, W * (1 - p), 0, 1); b.style.boxShadow = '-12px 0 24px rgba(0,0,0,.12)'; break;
        case 'scroll': place(a, 0, -H * .35 * p, 1 - p); place(b, 0, H * .35 * (1 - p), p); break;
        case 'tab': place(a, -40 * p, 0, 1 - p); place(b, 40 * (1 - p), 0, p); break;
        default: place(a, 0, 0, 1); place(b, 0, 0, p);
      }
    } else place(els[i], 0, 0, 1);
    const showBar = p < .5 && prev ? prev : cur;
    bar.style.background = showBar.bar;
    bar.classList.toggle('light', showBar.dark);
    const left = cur.t + cur.dur - t;
    if (cur.tap && left < TAP && i < T.length - 1) {
      const k = 1 - left / TAP;
      tap.style.left = cur.tap[0] + 'px'; tap.style.top = (cur.tap[1] + 44) + 'px';
      tap.style.opacity = k < .7 ? Math.min(1, k * 4) : (1 - k) / .3;
      tap.style.transform = `scale(${.6 + .5 * Math.min(1, k * 2)})`;
    } else tap.style.opacity = 0;
  }

  const orig = window.seek;
  window.seek = T2 => { orig(T2); realSeek(T2); };
  if (q.has('t')) window.seek(+q.get('t'));
})();
