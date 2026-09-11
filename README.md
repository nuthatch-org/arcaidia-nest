# arcaidia-nest

A [Nuthatch](https://github.com/nightswatchhq/nuthatch) index of the Arcaidia contracts on **Arc
Testnet** and **Ethereum Sepolia**, built from
[immaxkent/arcaidia](https://github.com/immaxkent/arcaidia)'s subgraph manifests and ABIs. Same
four contracts on each chain, every event in their ABIs (which includes the nine the subgraph
handles), plus six SQL views that reproduce the subgraph's entities by name.

It is hosted for the ETHOnline 2026 build. No API key, no quota, no rate limit, callable straight
from a browser.

## The URLs

| Chain | Base URL |
| --- | --- |
| Arc Testnet (5042002) | `https://hackathon.89.167.109.4.sslip.io/arcaidia-arc` |
| Ethereum Sepolia (11155111) | `https://hackathon.89.167.109.4.sslip.io/arcaidia-sepolia` |

Every route below is relative to one of those. `Access-Control-Allow-Origin: *` is set, so
`fetch()` from any page works.

```sh
curl https://hackathon.89.167.109.4.sslip.io/arcaidia-arc/ready
curl -G https://hackathon.89.167.109.4.sslip.io/arcaidia-arc/sql --data-urlencode 'q=SELECT * FROM protocol_state'
```

## Your subgraph queries, as SQL

The views carry the subgraph's entity names in snake case, so each of the agent's queries maps to
one statement. All of these were run against the live nests on 11 September 2026.

**PendingIntents** (`intents(where: { fastStatus: PENDING }, orderBy: createdAtTimestamp)`):

```sql
SELECT * FROM pending_intents LIMIT 50
```

**VaultState** (`vault(id: $vault)`):

```sql
SELECT * FROM vault WHERE id = '0xc74e693938dfbf7c11b787ba27cdde4c0215aaf1'
```

**ProtocolState** (`protocolState(id: "arcaidia")`):

```sql
SELECT * FROM protocol_state
```

**FillForIntent** (`fills(first: 1, where: { intentId: $id })`):

```sql
SELECT id FROM fills WHERE intent_id = '0xce0cee4f0691b25c7d98a32623e98a4752571d7aefd8bceb35b44d14b7b9742c' LIMIT 1
```

`_meta { block { timestamp } }` has no SQL equivalent because it is on every response already:
`provenance.as_of` is the block the answer is as of, and `GET /ready` carries `last_block`, `tip`
and `lag_blocks`.

A response, verbatim from the Sepolia nest on 11 September 2026 (`registry_hash` and `nid` cut):

```json
{"cached":false,"count":1,"degraded":false,"degraded_tables":[],
 "provenance":{"as_of":11681562,"entities":null,"sealed_through":11675226,"source":"hot+sealed"},
 "rows":[{"id":"arcaidia","intents_created":3,"intents_filled":0,"intents_settled":0,
          "oldest_unsettled_timestamp":0,"pending_settlement_value":"0","total_fees_earned":"0",
          "updated_at_block":11676357,"updated_at_timestamp":1789060836}],
 "tip_unavailable":false,"truncated":false}
```

Amounts come back as strings because they are exact. Parse them with `BigInt`.

## The views

| View | Subgraph entity | Notes |
| --- | --- | --- |
| `intents` | `Intent` | `fast_status` and `canonical_status` derived from fills and settlements on this chain |
| `fills` | `Fill` | one row per `FastFilled`; `id` is `txHash-logIndex` like the mapping's `eventId` |
| `settlements` | `Settlement` | both receivers, current and retired; `outcome` is `LP_REIMBURSED` or `RECIPIENT_FALLBACK` |
| `vault` | `Vault` | per vault address; the same arithmetic as `vault.ts`, computed from events |
| `protocol_state` | `ProtocolState` | the singleton; `id` is always `arcaidia` |
| `pending_intents` | the agent's query | `intents` with no fill, oldest first |

The SQL for each is in [`views/`](views/) and is short enough to read. `GET /schema` describes
every view and table with its columns.

## The cross-chain join is yours, as before

An intent is created on the source chain and filled and settled on the destination, so on Sepolia
the three intents read `PENDING` while Arc holds their fills and settlements. That is exactly the
state the subgraphs are in, and `GraphObservationProvider` already merges the two on `intentId`.
Point its two endpoints at the two nests and keep the merge.

If a merged view across both chains would help, ask; a nest is one chain by design, but a small
service in front of both is an afternoon.

## Raw tables

Every event in every ABI has a table named `alias__event`, 33 per chain. The aliases are
`intent_router`, `liquidity_vault`, `settlement_receiver` and `settlement_receiver_legacy`. Column
names follow the ABI parameter names, so quote them: `"intentId"`, `"outputAmount"`. A `uint256`
column is exact text; its `_dec` companion (`amount_dec`) is numeric, so sum and compare on that.

```sql
SELECT block_number, "intentId", "outputAmount_dec" FROM liquidity_vault__fast_filled ORDER BY block_number DESC LIMIT 10
```

`GET /tables` lists them all.

## Polling

There is no quota, so poll as you like. The efficient way is still to poll `GET /ready` and only run
the real queries when `last_block` moves. A block on Sepolia is 12 seconds; on Arc, well under one.

`/sql` admits two concurrent queries per nest and answers `503 server busy` to a third. Retry. A
query has a timeout and a row cap (`max_rows=` up to the cap); `truncated: true` tells you the cap
hit.

## Run it yourself

```sh
curl -fsSL https://nuthatch-indexer.com/install.sh | sh
nuthatch init --from https://github.com/nightswatchhq/arcaidia-nest
nuthatch dev --dir arcaidia-nest --window 4000 --finality-only --rpc https://arc-testnet.drpc.org
```

That is the Arc nest. The public Arc endpoints throttle a cold start, so give it one good `--rpc`
and a window of a few thousand blocks; the history is about 500,000 blocks and 30 events, and it
caught up in about three minutes on dRPC.

For Sepolia, `nuthatch.sepolia.toml` is the same contracts on chain 11155111. A nest is one chain
per process, so it runs from its own directory:

```sh
mkdir arcaidia-nest-sepolia && cp -R arcaidia-nest/{abis,views,semantic.toml} arcaidia-nest-sepolia/
cp arcaidia-nest/nuthatch.sepolia.toml arcaidia-nest-sepolia/nuthatch.toml
nuthatch schema --dir arcaidia-nest-sepolia
nuthatch dev --dir arcaidia-nest-sepolia --window 1280 --listen 127.0.0.1:8289
```

The Sepolia history is 21,000 blocks and catches up in three seconds on the public endpoint.

## Contracts

| Alias | Contract | Address (both chains, CREATE2) | Arc from block | Sepolia from block |
| --- | --- | --- | --- | --- |
| `intent_router` | ArcaidiaIntentRouter | `0x58868465d14e0694d033bD511588AE90482b21CC` | 61,236,176 | 11,667,863 |
| `liquidity_vault` | ArcaidiaLiquidityVault | `0xc74E693938DfBf7c11b787bA27cddE4c0215AAF1` | 61,414,683 | 11,675,651 |
| `settlement_receiver` | SettlementReceiver | `0x9a47a161ea8328b96Ad976264d42790881570E71` | 61,414,683 | 11,675,651 |
| `settlement_receiver_legacy` | SettlementReceiver, retired 2026-09-10 | `0xb634d0fDa74BacF730B1eF50a32b4c83f13f11fC` | 61,052,876 | 11,660,148 |

ABIs are vendored from the repository's `subgraph/abis/`, and declare the same events, signature for
signature, as the three ABI files the builder sent on 11 September. Every distinct event topic observed on
Arc, twenty of them, matches an event in those files; checked the same day.

## Help

[Night's Watch Discord](https://discord.gg/CQewvyJ69Y), or reply in the thread this came from.
