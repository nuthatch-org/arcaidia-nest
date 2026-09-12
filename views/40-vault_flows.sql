-- Per-vault money movement, folded from events with the same arithmetic the v1 vault view used:
-- liquid = deposits - withdrawals - advances + reimbursements; exposure = advances - cleared.
CREATE VIEW vault_flows AS
  WITH d AS (SELECT address AS vault, sum(assets_dec) AS deposited FROM "liquidity_vault__deposit" GROUP BY address),
       w AS (SELECT address AS vault, sum(assets_dec) AS withdrawn FROM "liquidity_vault__withdraw" GROUP BY address),
       f AS (SELECT address AS vault, sum("outputAmount_dec") AS advanced, count(*) AS fill_count FROM "liquidity_vault__fast_filled" GROUP BY address),
       r AS (SELECT address AS vault, sum("amountReceived_dec") AS received, sum("exposureCleared_dec") AS cleared FROM "liquidity_vault__reimbursement_recorded" GROUP BY address),
       p AS (SELECT address AS vault, sum("toProtocol_dec") AS protocol_fees, sum("toProtocol_dec" + "toLps_dec") AS total_fees FROM "liquidity_vault__fees_accrued" GROUP BY address),
       ps AS (SELECT address AS vault, arg_max(paused, block_number * 1000000 + log_index) AS paused FROM "liquidity_vault__paused_set" GROUP BY address),
       u AS (
         SELECT vault, max(block_number) AS updated_at_block, max(block_timestamp) AS updated_at_timestamp FROM (
           SELECT address AS vault, block_number, block_timestamp FROM "liquidity_vault__deposit"
           UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__withdraw"
           UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__fast_filled"
           UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__reimbursement_recorded"
           UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__fees_accrued"
           UNION ALL SELECT address, block_number, block_timestamp FROM "liquidity_vault__paused_set"
         ) GROUP BY vault
       )
  SELECT vp.vault,
         coalesce(d.deposited,0) - coalesce(w.withdrawn,0) - coalesce(f.advanced,0) + coalesce(r.received,0) AS liquid_balance,
         coalesce(f.advanced,0) - coalesce(r.cleared,0) AS outstanding_exposure,
         coalesce(p.protocol_fees,0) AS accrued_protocol_fees,
         coalesce(p.total_fees,0)    AS total_fees_earned,
         coalesce(d.deposited,0)     AS total_deposited,
         coalesce(w.withdrawn,0)     AS total_withdrawn,
         coalesce(f.fill_count,0)    AS fill_count,
         coalesce(ps.paused = 'true', false) AS paused,
         coalesce(u.updated_at_block, vp.created_at_block)         AS updated_at_block,
         coalesce(u.updated_at_timestamp, vp.created_at_timestamp) AS updated_at_timestamp
  FROM vault_policy vp
  LEFT JOIN d ON d.vault = vp.vault
  LEFT JOIN w ON w.vault = vp.vault
  LEFT JOIN f ON f.vault = vp.vault
  LEFT JOIN r ON r.vault = vp.vault
  LEFT JOIN p ON p.vault = vp.vault
  LEFT JOIN ps ON ps.vault = vp.vault
  LEFT JOIN u ON u.vault = vp.vault;
