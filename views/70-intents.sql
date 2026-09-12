-- The Intent entity. fast_status and canonical_status are derived from whether a fill or a
-- settlement exists for the intent on this chain, the same best-effort local join the mapping
-- does; an intent created on the other chain has no row here at all.
-- nonce stays on the raw text column: it is a random full-width uint256 and its _dec companion
-- overflows to NULL on every row.
CREATE VIEW intents AS
  SELECT i."intentId"                AS id,
         i.sender,
         i.recipient,
         i."intentVersion"       AS intent_version,
         i."inputToken"              AS input_token,
         i.amount_dec                AS amount,
         i."tokenOut"                AS token_out,
         i."targetMinOut_dec"      AS target_min_out,
         i."sourceChainId_dec"       AS source_chain_id,
         i."destinationChainId_dec"  AS destination_chain_id,
         i."maxFeeBps"           AS max_fee_bps,
         i.deadline,
         i.nonce,
         i."settlementRef"           AS settlement_ref,
         CASE WHEN f.id IS NULL THEN 'PENDING' ELSE 'FAST_FILLED' END AS fast_status,
         CASE WHEN s.id IS NULL THEN 'PENDING' ELSE 'SETTLED' END     AS canonical_status,
         i.block_number              AS created_at_block,
         i.block_timestamp           AS created_at_timestamp,
         i.tx_hash                   AS created_tx_hash,
         f.id                        AS fill,
         f.vault                     AS fill_vault,
         s.id                        AS settlement,
         s.outcome                   AS settlement_outcome
  FROM "intent_router__intent_created" i
  LEFT JOIN (SELECT intent_id, arg_min(id, block_number) AS id, arg_min(vault, block_number) AS vault
             FROM fills GROUP BY intent_id) f ON f.intent_id = i."intentId"
  LEFT JOIN (SELECT intent_id, arg_min(id, block_number) AS id, arg_min(outcome, block_number) AS outcome
             FROM settlements GROUP BY intent_id) s ON s.intent_id = i."intentId";
