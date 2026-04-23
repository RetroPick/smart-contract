# Market Type Approval Matrix

## Objective

Stage market-type rollout based on operational and settlement complexity.

## Approval Framework

For each market type, decide:

- launch now
- launch only with caps
- testnet only
- defer pending more review

## Review Dimensions

- oracle source complexity
- payout complexity
- rolling compatibility
- trusted-reporter dependence
- edge-case settlement risk
- operator burden

## Recommended Initial Bias

Launch earlier:

- simpler Chainlink-based threshold or direction styles

Launch later:

- trusted-reporter-dependent templates
- niche payout or multi-feed market types
- markets with harder-to-explain economic semantics

## Required Per-Type Review

- settlement formula summary
- expected oracle path
- likely failure modes
- user-experience risk if market halts or voids
- whether support team can explain outcomes clearly
