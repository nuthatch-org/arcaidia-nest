-- The subgraph's `Settlement` entity: LpReimbursed and RecipientPaidByFallback from both the
-- current receiver and the retired one, kept apart by `outcome` exactly as the mapping does.
CREATE VIEW settlements AS
  SELECT tx_hash || '-' || log_index AS id, "intentId" AS intent_id, 'LP_REIMBURSED' AS outcome,
         amount_dec AS amount, block_number, block_timestamp AS "timestamp", tx_hash, address AS receiver
  FROM "settlement_receiver__lp_reimbursed"
  UNION ALL
  SELECT tx_hash || '-' || log_index, "intentId", 'LP_REIMBURSED',
         amount_dec, block_number, block_timestamp, tx_hash, address
  FROM "settlement_receiver_legacy__lp_reimbursed"
  UNION ALL
  SELECT tx_hash || '-' || log_index, "intentId", 'RECIPIENT_FALLBACK',
         amount_dec, block_number, block_timestamp, tx_hash, address
  FROM "settlement_receiver__recipient_paid_by_fallback"
  UNION ALL
  SELECT tx_hash || '-' || log_index, "intentId", 'RECIPIENT_FALLBACK',
         amount_dec, block_number, block_timestamp, tx_hash, address
  FROM "settlement_receiver_legacy__recipient_paid_by_fallback";
