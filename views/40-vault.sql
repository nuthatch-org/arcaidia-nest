-- The subgraph's `Vault` entity, folded from events with the same arithmetic as vault.ts:
-- liquid = deposits - withdrawals - advances + reimbursements; exposure = advances - cleared.
-- `paused` is a text bool in the raw table, hence the comparison to 'true'.
CREATE VIEW vault AS
  WITH ev AS (
    SELECT address, block_number, block_timestamp FROM "liquidity_vault__deposit"
    UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__withdraw"
    UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__fast_filled"
    UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__reimbursement_recorded"
    UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__fees_accrued"
    UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__paused_set"
  ),
  u AS (SELECT address, max(block_number) AS updated_at_block, max(block_timestamp) AS updated_at_timestamp FROM ev GROUP BY address),
  d AS (SELECT address, sum(assets_dec) AS deposited FROM "liquidity_vault__deposit" GROUP BY address),
  w AS (SELECT address, sum(assets_dec) AS withdrawn FROM "liquidity_vault__withdraw" GROUP BY address),
  f AS (SELECT address, sum("outputAmount_dec") AS advanced, count(*) AS fill_count FROM "liquidity_vault__fast_filled" GROUP BY address),
  r AS (SELECT address, sum("amountReceived_dec") AS received, sum("exposureCleared_dec") AS cleared FROM "liquidity_vault__reimbursement_recorded" GROUP BY address),
  p AS (SELECT address, sum("toProtocol_dec") AS protocol_fees FROM "liquidity_vault__fees_accrued" GROUP BY address),
  ps AS (SELECT address, arg_max(paused, block_number * 1000000 + log_index) AS paused FROM "liquidity_vault__paused_set" GROUP BY address)
  SELECT u.address AS id,
         coalesce(d.deposited, 0) - coalesce(w.withdrawn, 0) - coalesce(f.advanced, 0) + coalesce(r.received, 0) AS liquid_balance,
         coalesce(f.advanced, 0) - coalesce(r.cleared, 0) AS outstanding_exposure,
         coalesce(p.protocol_fees, 0)                     AS accrued_protocol_fees,
         coalesce(d.deposited, 0)                         AS total_deposited,
         coalesce(w.withdrawn, 0)                         AS total_withdrawn,
         coalesce(f.fill_count, 0)                        AS fill_count,
         coalesce(ps.paused = 'true', false)              AS paused,
         u.updated_at_block,
         u.updated_at_timestamp
  FROM u
  LEFT JOIN d USING (address)
  LEFT JOIN w USING (address)
  LEFT JOIN f USING (address)
  LEFT JOIN r USING (address)
  LEFT JOIN p USING (address)
  LEFT JOIN ps USING (address);
