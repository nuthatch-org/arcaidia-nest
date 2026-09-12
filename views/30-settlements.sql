-- Canonical settlement. Three outcomes now: the LP was repaid, the recipient was paid directly
-- because nobody fast-filled, or the funds are held for a vault. `via_proof` and `cctp_nonce`
-- come from SettledWithProof, which is emitted alongside rather than instead of the outcome.
CREATE VIEW settlements AS
  WITH proof AS (
    SELECT "intentId", arg_min("cctpNonce", block_number) AS "cctpNonce"
    FROM "settlement_receiver__settled_with_proof" GROUP BY "intentId"
  ),
  raw AS (
    SELECT tx_hash, log_index, "intentId", 'LP_REIMBURSED' AS outcome, vault AS counterparty,
           vault AS held_for_vault, amount_dec AS amount, block_number, block_timestamp, address
    FROM "settlement_receiver__lp_reimbursed"
    UNION ALL
    SELECT tx_hash, log_index, "intentId", 'RECIPIENT_FALLBACK', recipient,
           NULL, amount_dec, block_number, block_timestamp, address
    FROM "settlement_receiver__recipient_paid_by_fallback"
    UNION ALL
    SELECT tx_hash, log_index, "intentId", 'HELD_FOR_VAULT', vault,
           vault, amount_dec, block_number, block_timestamp, address
    FROM "settlement_receiver__held_for_vault"
  )
  SELECT r.tx_hash || '-' || r.log_index AS id,
         r."intentId" AS intent_id,
         r.outcome,
         r.counterparty,
         r.held_for_vault,
         r.amount,
         (p."intentId" IS NOT NULL) AS via_proof,
         p."cctpNonce"              AS cctp_nonce,
         r.block_number,
         r.block_timestamp AS "timestamp",
         r.tx_hash,
         r.address AS receiver
  FROM raw r LEFT JOIN proof p ON p."intentId" = r."intentId";
