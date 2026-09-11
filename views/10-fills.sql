-- The subgraph's `Fill` entity: one row per FastFilled, id = txHash-logIndex as the mapping's
-- eventId does. Amounts are the _dec companions; the raw uint256 columns are exact text.
CREATE VIEW fills AS
  SELECT tx_hash || '-' || log_index AS id,
         "intentId"          AS intent_id,
         recipient,
         signer,
         "inputAmount_dec"   AS input_amount,
         "outputAmount_dec"  AS output_amount,
         "feeAmount_dec"     AS fee_amount,
         block_number,
         block_timestamp     AS "timestamp",
         tx_hash,
         address             AS vault
  FROM "liquidity_vault__fast_filled";
