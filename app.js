/* ===========================================================
   鸭狼展板 · 交互脚本
   互动观察装置：5 帧 / 0.9 秒的起跳咬人动作
   =========================================================== */
(function () {
  'use strict';

  var BASE = 'assets/frames/base.png';
  var FRAMES = [
    'assets/frames/frame-1.png', // 蓄力下蹲
    'assets/frames/frame-2.png', // 起跳
    'assets/frames/frame-3.png', // 扑咬（最高点）
    'assets/frames/frame-4.png', // 咬合
    'assets/frames/frame-5.png'  // 回落
  ];
  var FRAME_MS = 180;                 // 5 帧 × 180 ms = 0.9 s
  var BITING = [2, 3];                // 播放中出现“咬!”与震动的帧序号

  var stage = document.getElementById('stage');
  var stageImg = document.getElementById('stage-img');
  var burst = document.getElementById('burst');
  var btn = document.getElementById('feed-btn');
  var readout = document.getElementById('readout');
  var countEl = document.getElementById('count');
  if (!stage || !stageImg || !btn || !readout || !countEl) { return; }

  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var busy = false;
  var count = 0;
  var timer = null;

  // 预载全部帧，避免首帧闪烁
  FRAMES.concat([BASE]).forEach(function (src) { var im = new Image(); im.src = src; });

  var firstRemark = '咬！一次完整的起跳与咬人动作已完成。';
  var remarks = [
    '装置记录：咬合力度约 380 N（估值，属虚构数据）。',
    '提示：该动作属捕食反射，与参观者本人无关。',
    '它已回到展区角落，继续思考鸭生。',
    '本次动作未见异常，装置运行正常。',
    '展区玻璃完好，屏幕完好，手指完好。',
    '如需再看一次，请再按上方按钮。'
  ];

  function nextRemark() {
    if (count === 1) { return firstRemark; }
    return remarks[Math.floor(Math.random() * remarks.length)];
  }

  function setBiting(on) {
    burst.classList.toggle('show', on);
    if (!on) { stage.classList.remove('shake'); return; }
    if (reduced) { return; }
    stage.classList.remove('shake');
    void stage.offsetWidth;           // 重启动画
    stage.classList.add('shake');
  }

  function finish() {
    stageImg.src = BASE;
    setBiting(false);
    busy = false;
    btn.disabled = false;
    count += 1;
    countEl.textContent = String(count);
    readout.textContent = nextRemark();
    btn.querySelector('.btn-main').textContent = '再看一次跳起咬人';
  }

  function play() {
    if (busy) { return; }
    busy = true;
    btn.disabled = true;
    readout.textContent = '装置运行中：正在播放起跳与咬人的动作分解……';

    var i = 0;
    (function step() {
      if (i >= FRAMES.length) { timer = setTimeout(finish, FRAME_MS); return; }
      stageImg.src = FRAMES[i];
      setBiting(BITING.indexOf(i) !== -1);
      i += 1;
      timer = setTimeout(step, FRAME_MS);
    })();
  }

  btn.addEventListener('click', play);

  // 离开页面时清掉定时器
  window.addEventListener('pagehide', function () { if (timer) { clearTimeout(timer); } });

  // ---- 展板上的“扫码听鸣声”二维码（音频不存在，图案亦非真实二维码）----
  (function buildQr() {
    var el = document.getElementById('qr');
    if (!el) { return; }
    var N = 21, seed = 20190317;
    function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; }
    function inFinder(x, y) {
      return (x < 8 && y < 8) || (x > N - 9 && y < 8) || (x < 8 && y > N - 9);
    }
    var rects = '';
    for (var y = 0; y < N; y++) {
      for (var x = 0; x < N; x++) {
        if (inFinder(x, y)) { continue; }
        if (rnd() < 0.46) { rects += '<rect x="' + x + '" y="' + y + '" width="1" height="1"/>'; }
      }
    }
    function finder(ox, oy) {
      return '<rect x="' + ox + '" y="' + oy + '" width="7" height="7" fill="none" stroke="#2a241f" stroke-width="1"/>' +
             '<rect x="' + (ox + 2) + '" y="' + (oy + 2) + '" width="3" height="3"/>';
    }
    el.innerHTML = '<svg viewBox="0 0 ' + N + ' ' + N + '" shape-rendering="crispEdges" fill="#2a241f">' +
      rects + finder(0, 0) + finder(N - 7, 0) + finder(0, N - 7) + '</svg>';
  })();
})();
