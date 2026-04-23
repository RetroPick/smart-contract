<!DOCTYPE html>

<html lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>RetroPick - Portfolio and Rewards Management</title>
<!-- Tailwind CSS v3 CDN -->
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<script>
    tailwind.config = {
      theme: {
        extend: {
          colors: {
            'retro-dark': '#0b0e14',
            'retro-card': '#161b26',
            'retro-teal': '#4ade80',
            'retro-cyan': '#2dd4bf',
            'retro-magenta': '#d946ef',
            'retro-red': '#f43f5e',
            'retro-border': '#2d3748',
          }
        }
      }
    }
  </script>
<style data-purpose="custom-styling">
    body {
      background-color: #0b0e14;
      color: #ffffff;
      font-family: 'Inter', sans-serif;
    }
    .glass-card {
      background: linear-gradient(135deg, rgba(22, 27, 38, 0.8) 0%, rgba(22, 27, 38, 0.4) 100%);
      border: 1px solid rgba(255, 255, 255, 0.05);
      backdrop-filter: blur(10px);
    }
    .radial-progress {
      position: relative;
      width: 100px;
      height: 100px;
      border-radius: 50%;
      background: conic-gradient(#2dd4bf 0% 68%, #2d3748 68% 100%);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .radial-progress::before {
      content: "";
      position: absolute;
      width: 80px;
      height: 80px;
      background: #161b26;
      border-radius: 50%;
    }
    .sparkline-green {
      stroke: #4ade80;
      fill: none;
      stroke-width: 2;
    }
    .sparkline-cyan {
      stroke: #2dd4bf;
      fill: none;
      stroke-width: 2;
    }
  </style>
</head>
<body class="min-h-screen">
<!-- BEGIN: MainHeader -->
<header class="px-6 py-4">
<div class="bg-[#0b0e14]/80 backdrop-blur-md border border-white/10 rounded-3xl px-6 py-3 flex items-center justify-between">
<div class="flex items-center gap-10">
<!-- Logo -->
<div class="flex items-center gap-2 cursor-pointer">
<div class="w-9 h-9 bg-[#3b82f6] rounded-xl flex items-center justify-center shadow-[0_0_15px_rgba(59,130,246,0.5)]">
<span class="text-white italic font-black text-xl">R</span>
</div>
<span class="text-xl font-bold tracking-tight text-[#4f46e5]">Retropick</span>
</div>
<!-- Main Nav -->
<nav class="flex items-center bg-white/5 rounded-full p-1">
<a class="px-6 py-2 rounded-full text-sm font-bold text-gray-400 hover:text-white transition" href="#">MARKETS</a>
<a class="px-6 py-2 rounded-full text-sm font-bold bg-[#3b82f6] text-white shadow-[0_0_15px_rgba(59,130,246,0.3)]" href="#">PORTFOLIO</a>
<a class="px-6 py-2 rounded-full text-sm font-bold text-gray-400 hover:text-white transition" href="#">ACTIVITY</a>
<a class="px-6 py-2 rounded-full text-sm font-bold text-gray-400 hover:text-white transition" href="#">DRAFT</a>
<a class="px-6 py-2 rounded-full text-sm font-bold text-gray-400 hover:text-white transition" href="#">LIQUIDITY</a>
</nav>
</div>
<!-- Right Actions -->
<div class="flex items-center gap-3">
<!-- Network Selector -->
<div class="bg-[#161b22] border border-white/5 rounded-full px-4 py-2 flex items-center gap-2 cursor-pointer">
<span class="text-xs font-bold">Avalanche Fuji</span>
<svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewbox="0 0 24 24"><path d="M19 9l-7 7-7-7" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path></svg>
</div>
<!-- Balance/Wallet Pill -->
<div class="bg-[#161b22] border border-white/5 rounded-full pl-6 pr-1.5 py-1.5 flex items-center gap-3">
<div class="flex flex-col items-end">
<span class="text-[10px] text-gray-500 font-bold uppercase leading-none">Balance</span>
<span class="text-sm font-bold text-[#2dd4bf]">280.00 USDC</span>
</div>
<div class="w-8 h-8 rounded-full bg-gradient-to-br from-[#8b5cf6] to-[#ec4899]"></div>
</div>
</div>
</div>
<!-- Sub Nav & Search -->
<div class="mt-4 flex items-center justify-between px-2">
<div class="flex items-center gap-6">
<div class="bg-[#3b82f6]/10 border border-[#3b82f6]/20 rounded-full px-5 py-2">
<span class="text-xs font-bold text-[#3b82f6] uppercase tracking-wider">Trending</span>
</div>
<nav class="flex items-center gap-8">
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">New</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Macro</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Politics</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Sports</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Crypto</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Ai</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Commodities</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Space</a>
<a class="text-xs font-bold text-gray-500 hover:text-white uppercase tracking-wider transition" href="#">Corporate</a>
</nav>
</div>
<div class="relative flex-1 max-w-sm ml-12">
<div class="absolute inset-y-0 left-4 flex items-center pointer-events-none">
<svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewbox="0 0 24 24"><path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path></svg>
</div>
<input class="w-full bg-[#161b22]/50 border border-white/5 rounded-full py-2 pl-12 pr-4 text-sm focus:outline-none focus:border-[#3b82f6]/50 placeholder-gray-600" placeholder="Search markets..." type="text"/>
</div>
</div>
</header>
<!-- END: MainHeader -->
<!-- BEGIN: DashboardLayout -->
<main class="max-w-7xl mx-auto px-6 py-8 grid grid-cols-12 gap-6">
<!-- BEGIN: TopStatsSection -->
<div class="col-span-12 lg:col-span-9 grid grid-cols-1 md:grid-cols-3 gap-6">
<!-- Total PNL Card -->
<div class="glass-card rounded-3xl p-6 flex flex-col justify-between" data-purpose="stat-card-pnl">
<div>
<div class="flex items-center gap-2 text-gray-400 text-sm font-medium mb-1">
<span>Total PNL</span>
<svg class="h-4 w-4 text-retro-teal" fill="none" stroke="currentColor" viewbox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path d="M5 10l7-7m0 0l7 7m-7-7v18" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
</svg>
</div>
<div class="text-3xl font-bold text-retro-cyan">+$2,450.50 USDC</div>
</div>
<div class="mt-4">
<!-- Small Green Sparkline Placeholder -->
<svg class="w-full h-8 opacity-50" viewbox="0 0 100 30">
<path class="sparkline-green" d="M0 25 Q 10 20, 20 22 T 40 15 T 60 18 T 80 5 T 100 10"></path>
</svg>
</div>
</div>
<!-- Win Rate Card -->
<div class="glass-card rounded-3xl p-6 flex items-center justify-between" data-purpose="stat-card-winrate">
<div>
<div class="text-gray-400 text-sm font-medium mb-1">Win Rate</div>
<div class="text-3xl font-bold">68%</div>
</div>
<div class="radial-progress">
<span class="relative z-10 text-xs font-bold">68%</span>
</div>
</div>
<!-- Available to Claim Card -->
<div class="glass-card rounded-3xl p-6 flex flex-col justify-between" data-purpose="stat-card-claim">
<div>
<div class="text-gray-400 text-sm font-medium mb-1">Available to Claim</div>
<div class="text-3xl font-bold">$450.25 USDC</div>
</div>
<button class="mt-4 w-full bg-retro-cyan hover:bg-cyan-400 text-retro-dark font-bold py-2 rounded-xl transition">
          Claim All
        </button>
</div>
</div>
<!-- END: TopStatsSection -->
<!-- BEGIN: SidebarSection -->
<aside class="col-span-12 lg:col-span-3 row-span-2 flex flex-col gap-6">
<!-- Leaderboard -->
<div class="glass-card rounded-3xl p-6" data-purpose="sidebar-leaderboard">
<h3 class="text-xl font-bold mb-6">Leaderboard</h3>
<ul class="space-y-4">
<!-- Leaderboard Items -->
<li class="flex items-center justify-between text-sm">
<div class="flex items-center gap-3">
<span class="text-gray-500 w-4">1.</span>
<img alt="Avatar" class="w-8 h-8 rounded-full border border-retro-border" src="https://lh3.googleusercontent.com/aida-public/AB6AXuC0xL5LKKEEvVcWiIQj9nT70FJZejiUXMW7MRARc5AujsyuDnXM0OuhGnFW38WQY8EvX0VOlE8Uj_S37jEVkQZzbhg1oLcZ_3C1i_9KLx96Q8WCuHtl__Ti74ZRtJs6VGV-4pb2-IU81oLsFkBeiyqqk9oE5yBkdHhKatonOPwbZuUpbSt__O0Rce72vJOQ6BpqDhHaHgS12mKq3Bf4QXLFBXZdXA1ThPzGJZA8snShIAe222VvpsS4Z1dw3r_Tgs-oY80eLQY5X5k"/>
<span class="font-medium">CryptoKing</span>
</div>
<span class="text-retro-teal">+$15,200 PNL</span>
</li>
<li class="flex items-center justify-between text-sm">
<div class="flex items-center gap-3">
<span class="text-gray-500 w-4">2.</span>
<img alt="Avatar" class="w-8 h-8 rounded-full border border-retro-border" src="https://lh3.googleusercontent.com/aida-public/AB6AXuDKGJcMFpNbp2FB2Pa_3sM2IxIE3tfvZOr0u9dxl4mQ1cwQ68pIvOUsSR7Z7pCR6PuCZn7kj2ZOX_FFeFfZJZe6NUkkmWWgY2LMDVmQhDBa3SvH3sjocvSJ6N8Tc9cerzL8l9_b9877Qo7Nlau73pOjTWNjcqWh2qEp3-GqWUOA3GWwVcNEZkjnzauKbdN_j3bNYOhA_d6WkRjHlrK6zk-D_RofzDf2pxGZW8K2qQiOvlPGKKcG7c-1Pa8roWeyr2LM9QghkYjS3zE"/>
<span class="font-medium">SolanaWhale</span>
</div>
<span class="text-retro-teal">+$12,800 PNL</span>
</li>
<li class="flex items-center justify-between text-sm">
<div class="flex items-center gap-3">
<span class="text-gray-500 w-4">3.</span>
<img alt="Avatar" class="w-8 h-8 rounded-full border border-retro-border" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCrUr7BDxYeU2W99rOdYWFi_zgODjOrh18Ax_G3u6rgdpA0YhmgEo-PDtRU6q1j_XwHDLW-jPs2-n2RfgQVowbhsDtICteKP-L86VP9V24yAKNIDxgYg6p2q0t3kM6T088X2KVd0S9vLiH9z0EhRxJwa5I4xrdXloYteMbWth67qXsMy6PZf1RYydmtp0QD5AcD5dSm2j0oOK-3LLlsQcrzFzllqTU1PS5wYjro2Agc4qQtgozY9GCx5Kr7aRVIw-mN3pYGHNz1LGk"/>
<span class="font-medium">PredictorX</span>
</div>
<span class="text-retro-teal">+$10,500 PNL</span>
</li>
<li class="flex items-center justify-between text-sm bg-white/5 p-2 -mx-2 rounded-lg">
<div class="flex items-center gap-3">
<span class="text-gray-500 w-4">4.</span>
<img alt="Avatar" class="w-8 h-8 rounded-full border border-retro-cyan" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCnqZ0HUnXkJ-oP9G27Pyr5IirwbKA_TyC4R028kCfkWuhFjWahMIVsqgygP6DJmOvoft-B1djcuvztKcxWtLhvc0rGnjpz-QiPq3wK_zkoNpYhrP1EQYxyyGTtOzoLfSuw4_Cvy9p1NdzfaT97cPiAarqBuDTWgIlbYlh-snHhjJxXFhqXnXpYUk4pL_wRKMMM74IDpcEZKlKsqjfg6vTJljHrQjOhJkTtpQvKg3cCd4xNCMCiWRMbqp4zZtDm9t6LDwquBfZcAF8"/>
<span class="font-medium text-retro-cyan">PredictorX</span>
</div>
<span class="text-retro-teal">+$8,000 PNL</span>
</li>
<li class="flex items-center justify-between text-sm">
<div class="flex items-center gap-3">
<span class="text-gray-500 w-4">5.</span>
<img alt="Avatar" class="w-8 h-8 rounded-full border border-retro-border" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCeuN0LpHqmsr62VUAWA_wmRf2-ni9amjov9mHc1tZLS22n4-T6CCBtAWsS54WZfAc-vJSFdyud8MTiuoVUpcsURyaxOHb3aqaEY4hDfiq9yy5VCKePaaNbmBGMOZLbVqi3vr1MEILXDL4T3zDJ3jQc52J18brKNU4gpN45YaXBXQrMX5nJWsZFOMzKSo5ZDuubod_LXgz6EzTqkLcDtDt-48lTHmadbUH_8GkQWebLLglk96oIFUOkfTwFI229jN1VysPd0ulu1_w"/>
<span class="font-medium">CryptoLink</span>
</div>
<span class="text-retro-teal">+$5,000 PNL</span>
</li>
<li class="flex items-center justify-between text-sm">
<div class="flex items-center gap-3">
<span class="text-gray-500 w-4">6.</span>
<img alt="Avatar" class="w-8 h-8 rounded-full border border-retro-border" src="https://lh3.googleusercontent.com/aida-public/AB6AXuAKFP4TqHSod1-X09hrBl-JkMQlinTSyJpMjcApcXZkUkHYrXt08eM2zrJPimp1jl3T9w0YNlKUTvaQu_Mb937M8oxOS7sL_de4bMi4jPcwbJJVGiIIR4-dIkMSjcY4h9mD7F7UI7UD_lWI9CRac96NogUM_RLaCxmV8Yb7XHIOHtAncceHOoI11Pa2X99EILIW_lZWPpLGXVwQIth0wEkZQEOfqwidlKT6aM5IRYlqBftb_maqNOv77_G6Wb3yBxE7Nkqmnw0-NRo"/>
<span class="font-medium">Lemmeny</span>
</div>
<span class="text-retro-teal">+$2,500 PNL</span>
</li>
</ul>
</div>
<!-- Market Statistics -->
<div class="glass-card rounded-3xl p-6" data-purpose="sidebar-stats">
<h3 class="text-xl font-bold mb-6">Market Statistics</h3>
<div class="space-y-6">
<div>
<div class="flex items-center justify-between mb-2">
<div class="text-gray-400 text-sm">24h Volume</div>
<svg class="w-16 h-8" viewbox="0 0 50 20">
<path class="sparkline-cyan" d="M0 15 Q 10 5, 20 12 T 40 2 T 50 10"></path>
</svg>
</div>
<div class="text-2xl font-bold">$1.2M</div>
</div>
<div>
<div class="flex items-center justify-between mb-2">
<div class="text-gray-400 text-sm">Total Value Locked</div>
<svg class="w-16 h-8" viewbox="0 0 50 20">
<path class="sparkline-cyan" d="M0 18 Q 10 15, 20 10 T 40 5 T 50 2"></path>
</svg>
</div>
<div class="text-2xl font-bold">$5.5M</div>
</div>
</div>
</div>
</aside>
<!-- END: SidebarSection -->
<!-- BEGIN: PastRoundsSection -->
<div class="col-span-12 lg:col-span-9 glass-card rounded-3xl p-8" data-purpose="main-table-container">
<h2 class="text-2xl font-bold mb-6">Past Rounds</h2>
<div class="overflow-x-auto">
<table class="w-full text-left">
<thead>
<tr class="text-gray-500 text-sm border-b border-retro-border">
<th class="pb-4 font-medium">Round ID</th>
<th class="pb-4 font-medium">Market</th>
<th class="pb-4 font-medium">Direction</th>
<th class="pb-4 font-medium">Result</th>
<th class="pb-4 font-medium">Payout</th>
<th class="pb-4 font-medium">Action</th>
</tr>
</thead>
<tbody class="text-sm">
<!-- Table Row 1 -->
<tr class="border-b border-white/5 hover:bg-white/5 transition group">
<td class="py-5 text-gray-400">#456789</td>
<td class="py-5 font-bold">BTC/USD</td>
<td class="py-5 text-retro-cyan font-bold">UP</td>
<td class="py-5">
<span class="inline-flex items-center gap-1 bg-retro-teal/10 text-retro-teal px-2 py-1 rounded-full text-xs font-bold border border-retro-teal/20">
<svg class="h-3 w-3" fill="currentColor" viewbox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path clip-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" fill-rule="evenodd"></path></svg>
                  Win
                </span>
</td>
<td class="py-5 text-retro-teal font-medium">+$120.00 USDC</td>
<td class="py-5">
<button class="bg-retro-cyan/20 text-retro-cyan px-4 py-1.5 rounded-lg font-bold border border-retro-cyan/30 cursor-not-allowed opacity-80" disabled="">Claimed</button>
</td>
</tr>
<!-- Table Row 2 -->
<tr class="border-b border-white/5 hover:bg-white/5 transition group">
<td class="py-5 text-gray-400">#456788</td>
<td class="py-5 font-bold">ETH/USD</td>
<td class="py-5 text-retro-magenta font-bold">DOWN</td>
<td class="py-5">
<span class="inline-flex items-center gap-1 bg-retro-red/10 text-retro-red px-2 py-1 rounded-full text-xs font-bold border border-retro-red/20">
<svg class="h-3 w-3" fill="currentColor" viewbox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path clip-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" fill-rule="evenodd"></path></svg>
                  Loss
                </span>
</td>
<td class="py-5 text-retro-red font-medium">-$50.00 USDC</td>
<td class="py-5 text-center text-gray-600 font-bold">-</td>
</tr>
<!-- Table Row 3 -->
<tr class="border-b border-white/5 hover:bg-white/5 transition group">
<td class="py-5 text-gray-400">#456787</td>
<td class="py-5 font-bold">SOL/USD</td>
<td class="py-5 text-retro-cyan font-bold">UP</td>
<td class="py-5">
<span class="inline-flex items-center gap-1 bg-retro-teal/10 text-retro-teal px-2 py-1 rounded-full text-xs font-bold border border-retro-teal/20">
<svg class="h-3 w-3" fill="currentColor" viewbox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path clip-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" fill-rule="evenodd"></path></svg>
                  Win
                </span>
</td>
<td class="py-5 text-retro-teal font-medium">+$85.50 USDC</td>
<td class="py-5">
<button class="bg-retro-cyan hover:bg-cyan-400 text-retro-dark px-4 py-1.5 rounded-lg font-bold transition">Claim</button>
</td>
</tr>
<!-- Table Row 4 -->
<tr class="border-b border-white/5 hover:bg-white/5 transition group">
<td class="py-5 text-gray-400">#456786</td>
<td class="py-5 font-bold">ADA/USD</td>
<td class="py-5 text-retro-magenta font-bold">DOWN</td>
<td class="py-5">
<span class="inline-flex items-center gap-1 bg-retro-teal/10 text-retro-teal px-2 py-1 rounded-full text-xs font-bold border border-retro-teal/20">
<svg class="h-3 w-3" fill="currentColor" viewbox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path clip-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" fill-rule="evenodd"></path></svg>
                  Win
                </span>
</td>
<td class="py-5 text-retro-teal font-medium">+$30.10 USDC</td>
<td class="py-5">
<button class="bg-retro-cyan/20 text-retro-cyan px-4 py-1.5 rounded-lg font-bold border border-retro-cyan/30 cursor-not-allowed opacity-80" disabled="">Claimed</button>
</td>
</tr>
<!-- Table Row 5 -->
<tr class="hover:bg-white/5 transition group">
<td class="py-5 text-gray-400">#456785</td>
<td class="py-5 font-bold">BNB/USD</td>
<td class="py-5 text-retro-cyan font-bold">UP</td>
<td class="py-5">
<span class="inline-flex items-center gap-1 bg-retro-red/10 text-retro-red px-2 py-1 rounded-full text-xs font-bold border border-retro-red/20">
<svg class="h-3 w-3" fill="currentColor" viewbox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path clip-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" fill-rule="evenodd"></path></svg>
                  Loss
                </span>
</td>
<td class="py-5 text-retro-red font-medium">-$75.00 USDC</td>
<td class="py-5 text-center text-gray-600 font-bold">-</td>
</tr>
</tbody>
</table>
</div>
</div>
<!-- END: PastRoundsSection -->
</main>
<!-- END: DashboardLayout -->
</body></html>