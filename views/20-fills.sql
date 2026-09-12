-- One row per FastFilled. `vault` is the emitting vault, which is what makes a fill attributable
-- now that there is more than one. `delivered_via` is USDC unless a swap event names the intent.
CREATE VIEW fills AS
  SELECT f.tx_hash || '-' || f.log_index AS id,
         f."intentId"        AS intent_id,
         f.address           AS vault,
         f.recipient,
         f.signer,
         f."inputAmount_dec"  AS input_amount,
         f."outputAmount_dec" AS output_amount,
         f."feeAmount_dec"    AS fee_amount,
         f."feeBps"       AS fee_bps,
         CASE WHEN b."intentId" IS NOT NULL THEN 'SWAP_FALLBACK'
              WHEN s."intentId" IS NOT NULL THEN 'SWAP'
              ELSE 'USDC' END AS delivered_via,
         coalesce(s."tokenOut", b."tokenOut")          AS token_out,
         coalesce(s."amountOut_dec", b."usdcDelivered_dec") AS amount_out,
         f.block_number,
         f.block_timestamp   AS "timestamp",
         f.tx_hash
  FROM "liquidity_vault__fast_filled" f
  LEFT JOIN (SELECT "intentId", arg_min("tokenOut", block_number) AS "tokenOut",
                    arg_min("amountOut_dec", block_number) AS "amountOut_dec"
             FROM "liquidity_vault__delivered_via_swap" GROUP BY "intentId") s ON s."intentId" = f."intentId"
  LEFT JOIN (SELECT "intentId", arg_min("tokenOut", block_number) AS "tokenOut",
                    arg_min("usdcDelivered_dec", block_number) AS "usdcDelivered_dec"
             FROM "liquidity_vault__swap_fell_back" GROUP BY "intentId") b ON b."intentId" = f."intentId";
