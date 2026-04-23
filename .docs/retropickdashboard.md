<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>RetroPick Dashboard Recreation</title>
  <style>
    :root {
      --bg-1: #02091a;
      --bg-2: #06112b;
      --panel: rgba(17, 26, 46, 0.82);
      --panel-2: rgba(19, 27, 47, 0.92);
      --border: rgba(139, 178, 255, 0.14);
      --text: #f4f7ff;
      --muted: #95a4c7;
      --teal: #49f5df;
      --teal-2: #26d7c7;
      --pink: #ff44cc;
      --pink-2: #f760c7;
      --purple: #7a66ff;
      --green: #3ce7c8;
      --shadow-teal: 0 0 14px rgba(73, 245, 223, 0.42), 0 0 28px rgba(73, 245, 223, 0.16);
      --shadow-pink: 0 0 14px rgba(255, 68, 204, 0.34), 0 0 28px rgba(255, 68, 204, 0.16);
      --radius-xl: 24px;
      --radius-lg: 18px;
      --radius-md: 14px;
    }

    * { box-sizing: border-box; }

    html, body {
      margin: 0;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at 18% 10%, rgba(40, 90, 255, 0.16), transparent 28%),
        radial-gradient(circle at 80% 6%, rgba(255, 0, 174, 0.12), transparent 24%),
        radial-gradient(circle at 50% 100%, rgba(63, 209, 255, 0.08), transparent 32%),
        linear-gradient(180deg, #020817 0%, #04112a 35%, #030b1e 100%);
      min-height: 100vh;
    }

    body::before {
      content: "";
      position: fixed;
      inset: 0;
      pointer-events: none;
      background:
        repeating-linear-gradient(
          90deg,
          rgba(255,255,255,0.012) 0,
          rgba(255,255,255,0.012) 1px,
          transparent 1px,
          transparent 120px
        ),
        repeating-linear-gradient(
          180deg,
          rgba(255,255,255,0.01) 0,
          rgba(255,255,255,0.01) 1px,
          transparent 1px,
          transparent 120px
        );
      opacity: .18;
    }

    .shell {
      width: 1440px;
      max-width: calc(100vw - 36px);
      margin: 18px auto 36px;
    }

    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      padding: 10px 0 18px;
    }

    .topbar-left,
    .topbar-right {
      display: flex;
      align-items: center;
      gap: 18px;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
      font-size: 26px;
      font-weight: 800;
      letter-spacing: -.03em;
      text-shadow: 0 0 16px rgba(122, 102, 255, .18);
    }

    .brand-mark {
      width: 34px;
      height: 34px;
      border-radius: 10px;
      position: relative;
      background: linear-gradient(145deg, #6bd6ff 0%, #7f62ff 42%, #ff4cd7 100%);
      clip-path: polygon(0 12%, 52% 12%, 78% 28%, 78% 52%, 55% 67%, 78% 88%, 35% 88%, 0 56%);
      box-shadow: 0 0 28px rgba(114, 118, 255, .25);
    }

    .glass {
      background: linear-gradient(180deg, rgba(20, 28, 46, .82), rgba(14, 22, 40, .88));
      border: 1px solid rgba(170, 199, 255, 0.12);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.05), 0 18px 48px rgba(0,0,0,.32);
      backdrop-filter: blur(14px);
    }

    .pair-select, .network-pill, .wallet-btn {
      height: 56px;
      border-radius: 18px;
      display: flex;
      align-items: center;
      padding: 0 18px;
    }

    .pair-select {
      min-width: 184px;
      justify-content: space-between;
      gap: 16px;
      color: #dce7ff;
      font-weight: 600;
    }

    .pair-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .pair-icon {
      width: 20px;
      height: 20px;
      border-radius: 6px;
      background: linear-gradient(145deg, rgba(113, 108, 255, .95), rgba(69, 246, 223, .95));
      box-shadow: var(--shadow-teal);
      position: relative;
    }

    .pair-icon::before,
    .pair-icon::after {
      content: "";
      position: absolute;
      left: 4px;
      right: 4px;
      height: 2px;
      border-radius: 2px;
      background: rgba(5, 15, 30, 0.8);
    }

    .pair-icon::before { top: 6px; }
    .pair-icon::after { bottom: 6px; }

    .caret {
      width: 10px;
      height: 10px;
      border-right: 2px solid #b8c5e7;
      border-bottom: 2px solid #b8c5e7;
      transform: rotate(45deg) translateY(-2px);
      margin-top: -4px;
      opacity: .8;
    }

    .network-label {
      font-size: 18px;
      color: #b7c5e7;
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .dot {
      width: 11px;
      height: 11px;
      border-radius: 999px;
      background: #61ffad;
      box-shadow: 0 0 12px rgba(97, 255, 173, .75);
    }

    .wallet-btn {
      min-width: 226px;
      justify-content: center;
      font-size: 18px;
      font-weight: 700;
      color: #f8fbff;
      background:
        linear-gradient(180deg, rgba(30, 39, 64, 0.76), rgba(18, 25, 44, 0.94)),
        linear-gradient(90deg, rgba(72,246,223,.5), rgba(255,76,215,.42));
      border: 1px solid rgba(189, 214, 255, 0.18);
      box-shadow: inset 0 0 0 1px rgba(255,255,255,0.03), 0 0 24px rgba(168, 87, 255, .18);
      position: relative;
      overflow: hidden;
    }

    .wallet-btn::before {
      content: "";
      position: absolute;
      inset: 0;
      border-radius: inherit;
      padding: 1px;
      background: linear-gradient(90deg, rgba(72,246,223,.72), rgba(255,76,215,.72));
      -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
      -webkit-mask-composite: xor;
      mask-composite: exclude;
      opacity: .9;
      pointer-events: none;
    }

    .divider {
      height: 1px;
      background: linear-gradient(90deg, transparent, rgba(163, 190, 255, .26) 10%, rgba(163, 190, 255, .26) 90%, transparent);
      box-shadow: 0 0 16px rgba(88, 168, 255, 0.08);
      margin-bottom: 28px;
    }

    .dashboard {
      display: grid;
      grid-template-columns: 1.65fr .46fr;
      gap: 18px;
      align-items: start;
    }

    .chart-panel {
      border-radius: 22px;
      padding: 18px;
      min-height: 508px;
      position: relative;
      background:
        linear-gradient(180deg, rgba(15, 24, 43, 0.88), rgba(10, 18, 36, 0.96)),
        radial-gradient(circle at 20% 0%, rgba(70, 221, 255, .05), transparent 30%);
      border: 1px solid rgba(160, 191, 255, 0.12);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.04), 0 30px 60px rgba(0,0,0,.35);
    }

    .segment {
      width: max-content;
      display: inline-flex;
      align-items: center;
      padding: 7px;
      border-radius: 18px;
      background: rgba(42, 48, 67, .58);
      border: 1px solid rgba(173, 188, 223, 0.1);
      gap: 2px;
      margin-bottom: 16px;
    }

    .segment button {
      border: 0;
      background: transparent;
      color: #b5c2e4;
      min-width: 156px;
      height: 56px;
      border-radius: 14px;
      font-size: 18px;
      font-weight: 500;
      cursor: pointer;
    }

    .segment .active {
      color: #78ffef;
      position: relative;
      text-shadow: 0 0 18px rgba(73, 245, 223, .42);
    }

    .segment .active::after {
      content: "";
      position: absolute;
      left: 28px;
      right: 28px;
      bottom: 6px;
      height: 3px;
      border-radius: 999px;
      background: linear-gradient(90deg, rgba(73,245,223,.15), rgba(73,245,223,.95), rgba(73,245,223,.15));
      box-shadow: 0 0 14px rgba(73,245,223,.66);
    }

    .chart {
      height: 410px;
      position: relative;
      border-radius: 18px;
      overflow: hidden;
      background:
        linear-gradient(180deg, rgba(5, 12, 26, .5), rgba(6, 14, 27, .6)),
        repeating-linear-gradient(0deg, rgba(150, 177, 228, .09) 0, rgba(150, 177, 228, .09) 1px, transparent 1px, transparent 54px),
        repeating-linear-gradient(90deg, rgba(150, 177, 228, .08) 0, rgba(150, 177, 228, .08) 1px, transparent 1px, transparent 76px);
      border: 1px solid rgba(168, 197, 255, 0.08);
    }

    .price-axis {
      position: absolute;
      top: 28px;
      right: 12px;
      width: 90px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      height: calc(100% - 56px);
      text-align: right;
      font-size: 14px;
      color: rgba(206, 222, 255, 0.72);
      z-index: 2;
    }

    .x-axis {
      position: absolute;
      left: 28px;
      right: 92px;
      bottom: 10px;
      display: flex;
      justify-content: space-between;
      font-size: 14px;
      color: rgba(206, 222, 255, 0.75);
      z-index: 2;
    }

    .candles {
      position: absolute;
      left: 26px;
      right: 88px;
      top: 30px;
      bottom: 28px;
      display: flex;
      align-items: flex-end;
      gap: 10px;
    }

    .candle-col {
      position: relative;
      width: 18px;
      display: flex;
      justify-content: center;
      align-items: flex-end;
      flex: 0 0 auto;
    }

    .wick {
      position: absolute;
      width: 2px;
      border-radius: 2px;
      opacity: .95;
      bottom: var(--wick-bottom);
      height: var(--wick-height);
      background: var(--c);
      box-shadow: 0 0 8px color-mix(in oklab, var(--c) 52%, transparent);
    }

    .body {
      width: 12px;
      border-radius: 3px;
      height: var(--body-height);
      bottom: var(--body-bottom);
      position: absolute;
      background: linear-gradient(180deg, color-mix(in oklab, var(--c) 94%, white 8%), var(--c));
      box-shadow: 0 0 12px color-mix(in oklab, var(--c) 45%, transparent);
    }

    .teal { --c: #5cf0dd; }
    .red { --c: #e77a84; }

    .volumes {
      position: absolute;
      left: 26px;
      right: 88px;
      bottom: 28px;
      height: 80px;
      display: flex;
      align-items: flex-end;
      gap: 6px;
      opacity: .52;
    }

    .vol { width: 12px; border-radius: 2px 2px 0 0; background: rgba(93, 239, 222, 0.34); }
    .vol.red { background: rgba(226, 118, 162, 0.34); }

    .vline {
      position: absolute;
      top: 18px;
      bottom: 26px;
      width: 0;
      border-left: 2px dashed rgba(218, 231, 255, .75);
      z-index: 2;
    }

    .vline.lock { left: 67.8%; }
    .vline.close { left: 77.7%; }

    .vlabel {
      position: absolute;
      top: 10px;
      transform: translateX(-50%);
      font-size: 18px;
      color: rgba(246, 250, 255, 0.92);
      z-index: 3;
      letter-spacing: .02em;
    }

    .vlabel.lock { left: 67.8%; }
    .vlabel.close { left: 77.7%; }

    .floating-price {
      position: absolute;
      right: 78px;
      top: 177px;
      background: linear-gradient(180deg, rgba(70, 238, 208, .88), rgba(47, 207, 193, .88));
      color: white;
      font-weight: 700;
      font-size: 14px;
      padding: 6px 10px;
      border-radius: 6px;
      box-shadow: var(--shadow-teal);
      z-index: 3;
    }

    .tv-badge {
      position: absolute;
      left: 16px;
      bottom: 16px;
      width: 40px;
      height: 40px;
      border-radius: 999px;
      background: rgba(23, 31, 44, .88);
      display: grid;
      place-items: center;
      font-size: 18px;
      font-weight: 700;
      color: white;
      border: 1px solid rgba(255,255,255,.12);
      z-index: 3;
    }

    .side-stack {
      display: grid;
      gap: 18px;
    }

    .info-card {
      min-height: 168px;
      border-radius: 22px;
      padding: 24px 24px 20px;
      background: linear-gradient(180deg, rgba(17, 25, 45, 0.88), rgba(12, 20, 36, 0.96));
      border: 1px solid rgba(171, 195, 255, 0.12);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.04), 0 25px 40px rgba(0,0,0,.28);
    }

    .info-card h3 {
      margin: 0 0 16px;
      font-size: 22px;
      font-weight: 700;
      letter-spacing: -.02em;
    }

    .info-card hr {
      border: 0;
      height: 1px;
      background: rgba(255,255,255,.09);
      margin: 0 0 18px;
    }

    .rows {
      display: grid;
      gap: 16px;
    }

    .row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 14px;
      font-size: 16px;
    }

    .label { color: #b0bedf; }
    .value { color: #f6f8ff; font-weight: 600; }
    .profit { color: #d9e7ff; opacity: .88; }

    .rounds {
      margin-top: 22px;
      display: grid;
      grid-template-columns: 46px 1fr 1fr 1.05fr 1fr 46px;
      align-items: center;
      gap: 18px;
    }

    .arrow {
      width: 46px;
      height: 46px;
      display: grid;
      place-items: center;
      color: #d6e6ff;
      font-size: 36px;
      opacity: .72;
      user-select: none;
    }

    .market-card {
      position: relative;
      height: 348px;
      padding: 18px 18px 16px;
      color: #eaf3ff;
      background: linear-gradient(180deg, rgba(26, 31, 48, 0.88), rgba(17, 21, 34, 0.96));
      border: 1px solid rgba(176, 196, 255, .12);
      box-shadow: inset 0 1px 0 rgba(255,255,255,.03), 0 18px 28px rgba(0,0,0,.32);
      clip-path: polygon(12% 0, 88% 0, 100% 10%, 100% 90%, 88% 100%, 12% 100%, 0 90%, 0 10%);
      border-radius: 28px;
      overflow: hidden;
    }

    .market-card::before {
      content: "";
      position: absolute;
      inset: 8px;
      clip-path: inherit;
      border-radius: 24px;
      border: 1px solid rgba(255,255,255,.05);
      pointer-events: none;
    }

    .market-card.expired {
      opacity: .82;
      filter: saturate(.88);
    }

    .market-card.live {
      box-shadow: 0 0 0 1px rgba(118,255,235,.5), 0 0 18px rgba(96, 246, 220, .32), 0 0 38px rgba(255, 74, 211, .14), inset 0 1px 0 rgba(255,255,255,.04), 0 18px 28px rgba(0,0,0,.35);
    }

    .market-card.next {
      box-shadow: 0 0 0 1px rgba(118,255,235,.2), 0 0 22px rgba(118,255,235,.18), inset 0 1px 0 rgba(255,255,255,.04), 0 18px 28px rgba(0,0,0,.35);
    }

    .card-top {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 14px;
      color: #dce6ff;
      opacity: .95;
      margin-bottom: 18px;
      position: relative;
      z-index: 2;
    }

    .status-dot {
      width: 12px;
      height: 12px;
      border-radius: 999px;
      border: 2px solid currentColor;
      opacity: .8;
    }

    .expired .card-top { color: rgba(230, 236, 255, .48); }
    .live .card-top { color: #f0e8ff; }
    .next .card-top { color: #c8fff3; }

    .hex-center {
      position: absolute;
      left: 28px;
      right: 28px;
      top: 52px;
      height: 112px;
      clip-path: polygon(50% 0, 100% 33%, 100% 67%, 50% 100%, 0 67%, 0 33%);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      text-align: center;
      z-index: 1;
      background: linear-gradient(180deg, rgba(71, 242, 220, 0.75), rgba(71, 242, 220, 0.58));
      color: #e8fffb;
      box-shadow: inset 0 1px 0 rgba(255,255,255,.25), 0 0 16px rgba(73,245,223,.15);
    }

    .hex-center.down {
      top: auto;
      bottom: 14px;
      height: 92px;
      background: linear-gradient(180deg, rgba(255, 72, 207, 0.28), rgba(255, 72, 207, 0.16));
      color: #ff6dd5;
    }

    .live .hex-center {
      box-shadow: 0 0 18px rgba(73,245,223,.28), inset 0 1px 0 rgba(255,255,255,.22);
    }

    .hex-label {
      font-size: 17px;
      font-weight: 800;
      letter-spacing: .02em;
      text-transform: uppercase;
    }

    .hex-sub {
      font-size: 13px;
      opacity: .95;
      margin-top: 4px;
      font-weight: 600;
    }

    .inner-box {
      position: absolute;
      left: 22px;
      right: 22px;
      top: 118px;
      bottom: 58px;
      border-radius: 18px;
      background: linear-gradient(180deg, rgba(22, 27, 42, 0.95), rgba(20, 24, 36, 0.95));
      border: 2px solid rgba(91, 243, 227, 0.82);
      box-shadow: 0 0 10px rgba(73,245,223,.24), inset 0 1px 0 rgba(255,255,255,.05);
      padding: 16px 16px 14px;
      z-index: 2;
    }

    .expired .inner-box {
      border-color: rgba(108, 238, 220, 0.65);
    }

    .live .inner-box {
      box-shadow: 0 0 20px rgba(73,245,223,.28), inset 0 1px 0 rgba(255,255,255,.06);
    }

    .next .inner-box {
      top: 110px;
      bottom: 70px;
      border-color: rgba(165, 99, 255, 0.72);
      box-shadow: 0 0 16px rgba(160, 90, 255, .18);
    }

    .split-bar {
      height: 18px;
      border-radius: 999px;
      overflow: hidden;
      background: rgba(255,255,255,.04);
      display: flex;
      border: 1px solid rgba(255,255,255,.06);
      margin-bottom: 14px;
      font-size: 11px;
      font-weight: 800;
      line-height: 16px;
    }

    .split-bar span {
      display: flex;
      align-items: center;
      padding: 0 8px;
      white-space: nowrap;
    }

    .up-seg {
      width: var(--up, 50%);
      background: linear-gradient(90deg, rgba(66, 233, 211, .95), rgba(80, 242, 222, .74));
      color: #083634;
    }

    .down-seg {
      width: calc(100% - var(--up, 50%));
      justify-content: flex-end;
      background: linear-gradient(90deg, rgba(225, 91, 199, .72), rgba(255, 72, 207, .95));
      color: #451834;
    }

    .metric-title {
      color: rgba(220, 230, 255, .64);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: .02em;
      text-transform: uppercase;
    }

    .big-price {
      margin-top: 8px;
      font-size: 23px;
      font-weight: 800;
      letter-spacing: -.03em;
      text-shadow: 0 0 14px rgba(255,255,255,.05);
    }

    .submetrics {
      margin-top: 10px;
      display: grid;
      gap: 8px;
      color: #dce7ff;
      font-size: 15px;
    }

    .submetrics div {
      display: flex;
      justify-content: space-between;
      gap: 10px;
    }

    .submetrics span:first-child {
      color: rgba(220, 231, 255, .78);
    }

    .down-text {
      position: absolute;
      left: 0;
      right: 0;
      bottom: 18px;
      text-align: center;
      z-index: 2;
      font-size: 16px;
      font-weight: 800;
      color: #ff62d1;
      text-transform: uppercase;
      text-shadow: 0 0 10px rgba(255,98,209,.28);
    }

    .button-stack {
      display: grid;
      gap: 12px;
      margin-top: 18px;
    }

    .action-btn {
      height: 52px;
      border-radius: 14px;
      border: 0;
      font-size: 18px;
      font-weight: 800;
      letter-spacing: .01em;
      cursor: pointer;
      color: #f8fcff;
      box-shadow: inset 0 1px 0 rgba(255,255,255,.08), 0 12px 18px rgba(0,0,0,.18);
    }

    .btn-up { background: linear-gradient(180deg, #4ae9d2, #2fd2bf); color: #083b35; }
    .btn-down { background: linear-gradient(180deg, #ff50d3, #df41ad); }

    .next-head {
      position: absolute;
      left: 0;
      right: 0;
      top: 0;
      height: 34px;
      background: linear-gradient(90deg, #7b61ff, #54efe5);
      z-index: 0;
      opacity: .94;
    }

    @media (max-width: 1250px) {
      .dashboard { grid-template-columns: 1fr; }
      .rounds { grid-template-columns: 1fr 1fr; }
      .arrow { display: none; }
    }

    @media (max-width: 900px) {
      .topbar { flex-direction: column; align-items: stretch; }
      .topbar-left, .topbar-right { justify-content: space-between; flex-wrap: wrap; }
      .rounds { grid-template-columns: 1fr; }
      .segment button { min-width: 90px; }
      .chart-panel { min-height: 440px; }
      .chart { height: 340px; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <div class="topbar-left">
        <div class="brand">
          <div class="brand-mark"></div>
          <div>RetroPick</div>
        </div>

        <div class="pair-select glass">
          <div class="pair-left">
            <div class="pair-icon"></div>
            <div>SOL/USDC</div>
          </div>
          <div class="caret"></div>
        </div>
      </div>

      <div class="topbar-right">
        <div class="network-label">Solana Network: Connected <span class="dot"></span></div>
        <div class="wallet-btn">Connect Wallet</div>
      </div>
    </header>

    <div class="divider"></div>

    <section class="dashboard">
      <div class="chart-panel">
        <div class="segment">
          <button>Timeframe Selector</button>
          <button>5 MIN</button>
          <button class="active">1 HOUR</button>
          <button>1 DAY</button>
        </div>

        <div class="chart">
          <div class="vlabel lock">Lock</div>
          <div class="vlabel close">Close</div>
          <div class="vline lock"></div>
          <div class="vline close"></div>
          <div class="floating-price">$100.85</div>

          <div class="candles">
            <div class="candle-col red" style="--wick-bottom: 76px; --wick-height: 128px; --body-bottom: 92px; --body-height: 46px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 92px; --wick-height: 118px; --body-bottom: 112px; --body-height: 34px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 104px; --wick-height: 132px; --body-bottom: 126px; --body-height: 48px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col red" style="--wick-bottom: 114px; --wick-height: 116px; --body-bottom: 130px; --body-height: 42px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 126px; --wick-height: 145px; --body-bottom: 146px; --body-height: 58px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 172px; --wick-height: 122px; --body-bottom: 180px; --body-height: 30px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col red" style="--wick-bottom: 152px; --wick-height: 126px; --body-bottom: 160px; --body-height: 44px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 136px; --wick-height: 128px; --body-bottom: 154px; --body-height: 38px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col red" style="--wick-bottom: 120px; --wick-height: 136px; --body-bottom: 138px; --body-height: 54px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 146px; --wick-height: 122px; --body-bottom: 162px; --body-height: 28px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col red" style="--wick-bottom: 138px; --wick-height: 112px; --body-bottom: 154px; --body-height: 36px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 160px; --wick-height: 130px; --body-bottom: 174px; --body-height: 50px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col red" style="--wick-bottom: 148px; --wick-height: 118px; --body-bottom: 162px; --body-height: 30px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 154px; --wick-height: 148px; --body-bottom: 176px; --body-height: 58px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 236px; --wick-height: 128px; --body-bottom: 246px; --body-height: 46px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col red" style="--wick-bottom: 210px; --wick-height: 118px; --body-bottom: 220px; --body-height: 42px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col red" style="--wick-bottom: 176px; --wick-height: 112px; --body-bottom: 188px; --body-height: 34px;"><div class="wick"></div><div class="body"></div></div>
            <div class="candle-col teal" style="--wick-bottom: 182px; --wick-height: 96px; --body-bottom: 196px; --body-height: 22px;"><div class="wick"></div><div class="body"></div></div>
          </div>

          <div class="volumes">
            <div class="vol red" style="height: 24px"></div>
            <div class="vol" style="height: 38px"></div>
            <div class="vol" style="height: 28px"></div>
            <div class="vol red" style="height: 44px"></div>
            <div class="vol" style="height: 34px"></div>
            <div class="vol" style="height: 64px"></div>
            <div class="vol red" style="height: 48px"></div>
            <div class="vol" style="height: 52px"></div>
            <div class="vol red" style="height: 58px"></div>
            <div class="vol" style="height: 42px"></div>
            <div class="vol red" style="height: 40px"></div>
            <div class="vol" style="height: 60px"></div>
            <div class="vol red" style="height: 32px"></div>
            <div class="vol" style="height: 70px"></div>
            <div class="vol" style="height: 48px"></div>
            <div class="vol red" style="height: 82px"></div>
            <div class="vol red" style="height: 34px"></div>
            <div class="vol" style="height: 30px"></div>
          </div>

          <div class="price-axis">
            <span>2002.00</span>
            <span>1000.00</span>
            <span>1800.00</span>
            <span>1709.00</span>
            <span>1704.00</span>
            <span>1702.00</span>
            <span>1767.00</span>
          </div>

          <div class="x-axis">
            <span>11:00</span>
            <span>01:00</span>
            <span>03:30</span>
            <span>07:00</span>
            <span>04:00</span>
            <span>15</span>
            <span>04:32 PM</span>
            <span>05:32 PM</span>
          </div>

          <div class="tv-badge">TV</div>
        </div>
      </div>

      <div class="side-stack">
        <div class="info-card">
          <h3>My Position</h3>
          <hr />
          <div class="rows">
            <div class="row"><span class="label">Active Bets:</span><span class="value">0</span></div>
            <div class="row"><span class="label">Total P&amp;L:</span><span class="profit">+ 2.5 SOL</span></div>
          </div>
        </div>

        <div class="info-card">
          <h3>Market Info</h3>
          <hr />
          <div class="rows">
            <div class="row"><span class="label">Oracle:</span><span class="value">Chainlink</span></div>
            <div class="row"><span class="label">Resolution:</span><span class="value">5m Intervals</span></div>
            <div class="row"><span class="label">Settlement:</span><span class="value">Smart Contract</span></div>
          </div>
        </div>
      </div>
    </section>

    <section class="rounds">
      <div class="arrow">‹</div>

      <article class="market-card expired">
        <div class="card-top"><span class="status-dot"></span> Expired</div>
        <div class="hex-center">
          <div class="hex-label">UP</div>
          <div class="hex-sub">2.12x Payout</div>
        </div>
        <div class="inner-box">
          <div class="split-bar" style="--up: 60%;"><span class="up-seg">UP 60%</span><span class="down-seg">DOWN 40%</span></div>
          <div class="metric-title">Closed Price</div>
          <div class="big-price">$679.2925</div>
          <div class="submetrics">
            <div><span>Locked Price:</span><span>$676.6001</span></div>
            <div><span>Prize Pool:</span><span>2.2310 BNB</span></div>
          </div>
        </div>
        <div class="down-text">1.50x Payout<br>DOWN</div>
      </article>

      <article class="market-card expired">
        <div class="card-top"><span class="status-dot"></span> Expired</div>
        <div class="hex-center">
          <div class="hex-label">UP</div>
          <div class="hex-sub">2.12x Payout</div>
        </div>
        <div class="inner-box">
          <div class="split-bar" style="--up: 57%;"><span class="up-seg">UP 57%</span><span class="down-seg">DOWN 43%</span></div>
          <div class="metric-title">Closed Price</div>
          <div class="big-price">$679.2925</div>
          <div class="submetrics">
            <div><span>Locked Price:</span><span>$676.6501</span></div>
            <div><span>Prize Pool:</span><span>2.2310 BNB</span></div>
          </div>
        </div>
        <div class="down-text">1.65x Payout<br>DOWN</div>
      </article>

      <article class="market-card live">
        <div class="card-top"><span class="status-dot"></span> LIVE</div>
        <div class="hex-center">
          <div class="hex-label">UP</div>
          <div class="hex-sub">2.16x Payout</div>
        </div>
        <div class="inner-box">
          <div class="split-bar" style="--up: 65%;"><span class="up-seg">65% 65%</span><span class="down-seg">GOWN 35%</span></div>
          <div class="metric-title">Last Price</div>
          <div class="big-price">$678.8977</div>
          <div class="submetrics">
            <div><span>Locked Price:</span><span>$676.2255</span></div>
            <div><span>Prize Pool:</span><span>1.3403 BNB</span></div>
          </div>
        </div>
        <div class="down-text">1.85x Payout<br>DOWN</div>
      </article>

      <article class="market-card next">
        <div class="next-head"></div>
        <div class="card-top"><span class="status-dot"></span> Next</div>
        <div class="hex-center">
          <div class="hex-label">UP</div>
        </div>
        <div class="inner-box">
          <div class="split-bar" style="--up: 50%;"><span class="up-seg">UP 50%</span><span class="down-seg">DOWN 50%</span></div>
          <div class="submetrics" style="margin-top:10px; gap: 14px;">
            <div><span>Prize Pool:</span><span>&lt;0,0001 BNB</span></div>
          </div>
          <div class="button-stack">
            <button class="action-btn btn-up">ENTER UP</button>
            <button class="action-btn btn-down">ENTER DOWN</button>
          </div>
        </div>
      </article>

      <div class="arrow">›</div>
    </section>
  </div>
</body>
</html>
