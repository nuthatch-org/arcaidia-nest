-- Protocol-wide aggregates, the singleton keyed 'arcaidia'.
--
-- Two definitions are inferred rather than given, and are one line each to change:
-- trade_intents_created counts intents whose tokenOut is not the zero address, that is, the ones
-- asking for a token other than the input; intents_fallen_back counts SwapFellBack events.
CREATE VIEW protocol_state AS
  WITH ev AS (
    SELECT block_number, block_timestamp FROM "intent_router__intent_created"
    UNION ALL SELECT block_number, block_timestamp FROM "liquidity_vault__fast_filled"
    UNION ALL SELECT block_number, block_timestamp FROM "liquidity_vault__reimbursement_recorded"
    UNION ALL SELECT block_number, block_timestamp FROM "liquidity_vault__fees_accrued"
    UNION ALL SELECT block_number, block_timestamp FROM "vault_factory__vault_created"
    UNION ALL SELECT block_number, "timestamp" FROM settlements
  ),
  created AS (
    SELECT count(*) AS intents_created,
           count(*) FILTER (WHERE "tokenOut" <> '0x0000000000000000000000000000000000000000') AS trade_intents_created
    FROM "intent_router__intent_created"
  ),
  filled  AS (SELECT count(*) AS intents_filled, coalesce(sum(output_amount),0) AS advanced, min("timestamp") AS first_fill_ts FROM fills),
  settled AS (SELECT count(*) AS intents_settled FROM settlements),
  reimb   AS (SELECT coalesce(sum("exposureCleared_dec"),0) AS cleared FROM "liquidity_vault__reimbursement_recorded"),
  fees    AS (SELECT coalesce(sum("toProtocol_dec" + "toLps_dec"),0) AS total_fees FROM "liquidity_vault__fees_accrued"),
  vc      AS (SELECT count(*) AS vault_count FROM "vault_factory__vault_created"),
  fb      AS (SELECT count(*) AS intents_fallen_back FROM "liquidity_vault__swap_fell_back"),
  upd     AS (SELECT max(block_number) AS updated_at_block, max(block_timestamp) AS updated_at_timestamp FROM ev)
  SELECT 'arcaidia' AS id,
         created.intents_created,
         created.trade_intents_created,
         filled.intents_filled,
         settled.intents_settled,
         fb.intents_fallen_back,
         vc.vault_count,
         filled.advanced - reimb.cleared AS pending_settlement_value,
         CASE WHEN filled.advanced - reimb.cleared > 0 THEN filled.first_fill_ts ELSE 0 END AS oldest_unsettled_timestamp,
         fees.total_fees AS total_fees_earned,
         upd.updated_at_block, upd.updated_at_timestamp
  FROM created, filled, settled, reimb, fees, vc, fb, upd;
