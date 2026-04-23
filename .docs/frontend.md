1. Purpose

RetroPick V1 frontend is the primary user surface for interacting with oracle-resolved scheduled event contracts on Solana.

The frontend should help users do five things clearly:

understand the market

understand how the market resolves

enter a position quickly

monitor the round in real time

claim rewards after settlement

The UI must feel like a real market product, not a gambling page.
It should look:

premium

fast

crypto-native

transparent

deterministic

trustworthy

2. Product Positioning in the Frontend

The frontend should communicate that RetroPick is:

a prediction market product

based on machine-resolved outcomes

powered by public oracle data

optimized for scheduled rounds

simpler than an exchange

more expressive than a basic up/down timer

The UI should avoid feeling like:

a meme casino

a random betting page

a toy chart app

a cluttered exchange terminal

3. Frontend Goals
Primary goals

make round participation easy

make resolution logic obvious

make active markets visually strong

make countdown urgency visible

make settlement trust visible

make claims simple

Secondary goals

make market history easy to scan

make portfolio state easy to monitor

support future market templates

create a consistent visual system for V2 expansion

4. UX Principles
4.1 One card should explain one market

A user should understand a round from one card without opening another screen.

Each market card should clearly show:

market title

timeframe

status

lock rule

close rule

oracle source

live or final price

payout view

pool split

entry action or claim state

4.2 Rules before hype

Resolution logic should be more visible than visual decoration.

The frontend should always prioritize:

lock price

close price

resolution formula

oracle source

timestamps

claim state

4.3 Fast action, low confusion

The most important action should always be obvious.

Examples:

during entry phase: Enter UP / Enter DOWN

after settlement: Claim Rewards

during locked/live phase: disabled entry, clear waiting state

4.4 Scheduled markets must feel structured

Time-based markets need strong timing signals.

The UI should clearly display:

opens in

locks in

closes in

resolved

claimable

4.5 Premium DeFi, not casino

Use visual energy, but keep credibility.

That means:

restrained glow effects

strong typography

dark dashboard look

clean chart framing

transparent data panels

no childish illustrations in core trading flow

5. Visual Design Direction
5.1 Tone

RetroPick visual identity should feel:

sharp

high-signal

dark and modern

slightly futuristic

neon-accented but controlled

trustworthy for money actions

5.2 Core palette
Background

deep midnight blue

dark navy

charcoal with cool undertones

Positive / UP

electric teal

aqua glow

green-cyan accents

Negative / DOWN

vivid magenta

hot pink

red-pink gradients

Neutral / Brand

soft purple accents

steel blue borders

muted gray text

Warning / timer

subtle yellow or amber only when needed

5.3 Surface style

glass-dark cards

rounded corners

clean inner borders

subtle gradients

depth through shadow and glow

layered panels

6. Information Hierarchy

The frontend should visually prioritize information in this order:

Level 1

active market

chart

current round status

countdown

entry actions

Level 2

live price

lock price

prize pool

payout

side split

Level 3

oracle source

settlement rule

market metadata

user positions

round history

7. Main Frontend Screens
7.1 Main Trading Dashboard

This is the primary screen.

Main sections

top navigation

market selector

network/wallet area

chart area

active market panel

side information panels

round carousel/history

claim/position access

This should be the screen users spend most of their time on.

7.2 Market Detail View

Used when a user wants deeper explanation.

Should include

full market rule

oracle feed details

round lifecycle

lock timestamp

close timestamp

resolution formula

fee explanation

invalid/refund conditions

historical round list

7.3 Portfolio / My Positions

Used to view user participation.

Should include

active positions

pending rounds

resolved rounds

claimable rewards

claimed rewards

PnL-style history summary

wallet-linked activity

7.4 Claim Screen / Claim Panel

Used for post-settlement actions.

Should include

claimable rounds

claim amount

winning side

final settlement values

claim status

transaction feedback

7.5 History Screen

Used to review past rounds.

Should include

round ID

market name

lock price

close price

result

payout multiplier

total pool

oracle source

settlement timestamp

8. Core Layout
8.1 Top Navigation
Purpose

Persistent app control and identity.

Contents

RetroPick logo

market selector dropdown

network status

wallet connect button

optional tabs:

Markets

Portfolio

History

Docs

UX behavior

sticky on desktop

compact on mobile

wallet state always visible

market switch should not feel buried

8.2 Hero / Header Context

Optional lightweight explanatory strip above chart.

Good content

Oracle-resolved event contracts on Solana

Machine-settled, scheduled markets

Transparent rules and payout logic

This area should be concise, not marketing-heavy.

8.3 Chart Area
Purpose

Give market context, not full exchange complexity.

Must show

candlestick chart

price scale

time scale

lock marker

close marker

live price indicator

Nice to have

volume bars

oracle marker

hover tooltip

timeframe selector

UX principle

Chart should support user confidence, not overwhelm the screen.

8.4 Active Market Panel

This is the most important component.

Must show

market title

market type

round ID

round status

countdown

live price

lock price

oracle source

total pool

payout view

side split

main entry buttons

Buttons

Enter UP

Enter DOWN

State rules

when open: buttons enabled

when locked: disabled, show locked state

when live: show waiting/resolution state

when resolved: show result and claim

when claimable: highlight claim action

8.5 Side Info Panels
Recommended cards

My Position

Market Info

Claimable Rewards

Resolution Details

Why

These reduce clutter in the main market card while still exposing key trust data.

8.6 Round Carousel / Market Strip
Purpose

Show temporal flow across rounds.

Round types shown

expired

resolved

live

next

later

What each card should show

state

round ID

market direction/options

payout

lock/final price

prize pool

action state

UX principle

The carousel helps users understand scheduled repetition and upcoming opportunities.

9. Core UI Components
9.1 Wallet Connect Button
States

disconnected

connecting

connected

wrong network

loading balance

Behavior

prominent in header

visually premium

should open wallet modal fast

9.2 Market Selector
Purpose

Switch between supported markets.

Examples

BTC/USD 5m

ETH/USD 5m

SOL/USD 5m

BTC threshold daily close

ETH vs BTC 24h

UX behavior

searchable if list grows

grouped by market type later

9.3 Status Badge
States

Open

Locked

Live

Resolved

Claimable

Invalid

Refunded

Design

Use clear color states, but keep labels explicit.

9.4 Countdown Timer
Purpose

Create urgency and clarity.

Display modes

opens in

locks in

closes in

claimable now

UX rule

Do not show time without context.
Always pair with a state label.

9.5 Pool Split Bar
Purpose

Show relative participation.

Good display

UP 60%

DOWN 40%

This is both informative and emotionally engaging.

9.6 Resolution Details Panel
Must show

oracle source

lock rule

close rule

exact resolution formula

fee note

refund condition

This is a trust-critical component.

10. Supported Market Templates in UI

RetroPick V1 should support multiple templates within one design system.

10.1 Direction Market

Example: BTC up or down in 5 minutes

UI pattern

two-sided buttons

UP / DOWN

lock price vs close price

payout split

strongest and simplest layout

10.2 Threshold Market

Example: BTC above 110k by daily close

UI pattern

Yes / No or Above / Below

threshold value emphasized

close timestamp emphasized

binary result badge

10.3 Range Close Market

Example: ETH closes in one of four bins

UI pattern

multiple range options

selected bin highlighting

final close marker

payout by bin

UX note

This should be more structured than direction markets, with emphasis on range labels.

10.4 Relative Performance Market

Example: ETH outperforms BTC over 24h

UI pattern

asset A vs asset B

comparative performance rule

oracle input explanation

final winner state

11. Frontend States
11.1 App-level states

wallet disconnected

wallet connected

loading market data

websocket connected

websocket reconnecting

transaction pending

transaction success

transaction failed

11.2 Market-level states

scheduled

open

locked

live

resolved

claimable

invalid

refunded

11.3 Position-level states

no position

entered up

entered down

won

lost

claimable

claimed

12. User Flows
12.1 First-time Visitor Flow
Goal

Understand product quickly and connect wallet.

Flow

user lands on homepage/dashboard

sees active market and chart

sees short explanation of oracle-resolved market

sees market selector and live status

clicks connect wallet

wallet modal opens

user connects wallet

UI switches to connected state

user sees available actions

UX focus

reduce cognitive load

explain resolution clearly

keep first action close to active market

12.2 Enter Round Flow
Goal

Place a position in an active open round.

Flow

user selects market

frontend loads current round

card shows:

status open

countdown to lock

pool split

payout

user clicks Enter UP or Enter DOWN

entry modal opens

user chooses amount

modal shows:

side selected

fee

lock timestamp

wallet balance

user confirms

wallet signs transaction

transaction pending state shown

success toast shown

active position updates in UI

UX requirements

action should feel fast

modal should not hide critical round details

show exact entered side and amount before sign

12.3 Locked Round Flow
Goal

Help user understand waiting state.

Flow

countdown reaches lock

entry buttons disable

status changes to Locked or Live

lock price becomes fixed

user can no longer enter

UI highlights waiting for close/resolution

UX requirements

clear visual state change

no ambiguity about whether entry is still allowed

lock price must be prominent

12.4 Resolution Flow
Goal

Make settlement understandable and trustworthy.

Flow

round reaches close timestamp

oracle read is finalized

close price appears

resolution formula is applied

winning side is displayed

payout state becomes visible

losing state is clearly marked

claim button appears for winners

UX requirements

show both lock price and close price

show final result explicitly

show oracle source and formula nearby

12.5 Claim Rewards Flow
Goal

Claim winnings simply and confidently.

Flow

round becomes claimable

claim panel highlights pending rewards

user opens claimable positions

user sees:

market

round ID

result

claim amount

user clicks Claim

wallet signs claim transaction

pending state shown

claim confirmed

UI updates to Claimed

UX requirements

claim CTA should be obvious

avoid making user search for claim state

show transaction result clearly

12.6 Portfolio Review Flow
Goal

Help users track participation over time.

Flow

user opens Portfolio

sees summary:

active rounds

claimable rewards

settled history

can filter by:

active

resolved

claimable

claimed

opens round detail if needed

UX requirements

summary first, details second

claimable items should be prioritized

filters should be easy to use

13. Suggested Screen-by-Screen Structure
13.1 Main Dashboard

top nav

market selector

network + wallet

chart

active round card

position panel

market info panel

round carousel

claim summary

13.2 Entry Modal

market name

side selected

amount input

balance

fee

lock time

confirm button

13.3 Resolution Modal / Detail

oracle source

lock price

close price

resolution formula

final outcome

payout breakdown

13.4 Portfolio

balance / positions summary

active positions list

claimable positions list

settled history

14. Microcopy Guidelines

Use language that feels like a serious financial product.

Good copy

Oracle-resolved

Lock price captured

Deterministic settlement

Scheduled close

Claim rewards

Finalized

Settlement pending

Transparent rule set

Avoid

Bet big

Win crazy

Lucky guess

Jackpot

Moon shot vibes

15. Interaction and Motion
Recommended motion

soft hover glow

subtle countdown pulse

entry confirmation animation

claim success confirmation

smooth state transitions between open, locked, live, resolved

Avoid

noisy bouncing

slot-machine movement

excessive flash effects

childish reward animation

16. Responsive UX
Desktop

Primary experience:

chart + active card + side panels visible together

carousel below

information dense but readable

Tablet

stack side panels below chart

preserve active round priority

Mobile

top nav simplified

chart compact

active round card becomes primary hero

bottom sheet for entry modal

portfolio and history accessible via tabs

Mobile priority order

active round

entry action

countdown

chart

my position

round history

17. Accessibility and Clarity
Must-have

strong text contrast

large action buttons

readable timers

explicit labels, not icon-only actions

keyboard support for modals

not relying only on color for status

Why

Users are making money decisions.
Ambiguity is expensive.

18. Trust and Transparency Layer

RetroPick’s frontend edge is not just aesthetics.
It is clarity of deterministic settlement.

Every market should make visible:

what is being measured

when lock happens

when close happens

which oracle is used

how the winner is determined

when refunds happen if data is invalid

This is one of the most important frontend requirements.

19. Recommended Frontend Data Model Mapping

The UI should map backend/onchain data into these frontend concepts:

Market

id

title

type

asset

timeframe

oracle source

resolution rule

Round

id

market id

status

open time

lock time

close time

lock price

live price

close price

total pool

side totals

payout estimate

Position

user

round id

side

amount

claim status

outcome

payout amount

20. Suggested Navigation Model
Primary navigation

Markets

Portfolio

History

Docs

Secondary actions

Connect Wallet

Claim Rewards

Market Filter

Timeframe Selector

21. V1 Frontend Scope
Must ship

main dashboard

wallet connect

market selector

active round card

chart

entry modal

round state updates

claim flow

portfolio basics

history basics

Nice to have

filters

notifications

resolution detail modal

richer analytics

watchlist

favorite markets

22. Final UX Summary

RetroPick V1 frontend should feel like:

a premium market dashboard

built for short, repeatable, oracle-settled event contracts

with clear round timing

clear payout logic

clear resolution rules

and simple wallet-based actions

The app flow should always move the user through this sequence:

discover market → understand rule → enter round → wait for close → verify result → claim reward

That loop is the core of the product.