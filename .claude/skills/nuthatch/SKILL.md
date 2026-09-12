---
name: nuthatch
description: Query this self-hosted nuthatch nest on arc-testnet - decoded events, balances, and read-only SQL. Use when asked about on-chain activity for these contracts.
---

# Querying the nuthatch nest

Contracts indexed on arc-testnet:
- `intent_router` = 0x69946ffbbe5f250c7357b89e4072f9eafc1c3ee6
- `vault_factory` = 0xd458d83c874296ec4a29c47655ae47302879b23a
- `settlement_receiver` = 0x8b93b54d6df61e9422d14c309f3c9ab950b920cd

Data is local - never call an external API for it.

## Preferred: MCP
If a `nuthatch` MCP server is configured, use its tools. Call `schema` first to learn the
data model, then `sql` / `entity` / `balance` / `top_balances`.

## Fallback: HTTP (a `nuthatch dev` must be running)
- Recent rows:  `curl localhost:8288/entities?limit=20`
- Read-only SQL: `curl -G localhost:8288/sql --data-urlencode 'q=SELECT count(*) FROM transfers'`

`sql` sees finalized data only; balances/entity cover the live tip.
