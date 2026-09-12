-- One row per vault state change: the running balances after each event that moves them, and the
-- utilisation and fee those balances imply. Same ladder as `vaults`, evaluated at every step.
CREATE VIEW fee_snapshots AS
  WITH ev AS (
    SELECT address AS vault, block_number, block_timestamp, log_index,
           -"outputAmount_dec" AS d_liquid, "outputAmount_dec" AS d_exposure FROM "liquidity_vault__fast_filled"
    UNION ALL SELECT address, block_number, block_timestamp, log_index, assets_dec, 0 FROM "liquidity_vault__deposit"
    UNION ALL SELECT address, block_number, block_timestamp, log_index, -assets_dec, 0 FROM "liquidity_vault__withdraw"
    UNION ALL SELECT address, block_number, block_timestamp, log_index, "amountReceived_dec", -"exposureCleared_dec" FROM "liquidity_vault__reimbursement_recorded"
  ),
  run AS (
    SELECT vault, block_number, block_timestamp, log_index,
           sum(d_liquid)   OVER (PARTITION BY vault ORDER BY block_number, log_index
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS liquid_balance,
           sum(d_exposure) OVER (PARTITION BY vault ORDER BY block_number, log_index
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS outstanding_exposure
    FROM ev
  )
  SELECT r.vault, r.liquid_balance, r.outstanding_exposure,
         CASE WHEN r.liquid_balance + r.outstanding_exposure > 0
              THEN CAST(r.outstanding_exposure * 10000 / (r.liquid_balance + r.outstanding_exposure) AS BIGINT)
              ELSE 0 END AS utilisation_bps,
         CASE
           WHEN r.liquid_balance + r.outstanding_exposure <= 0 THEN vp."policy_baseFeeBps"
           WHEN r.outstanding_exposure * 10000 / (r.liquid_balance + r.outstanding_exposure) >= vp."policy_criticalThresholdBps" THEN vp."policy_criticalFeeBps"
           WHEN r.outstanding_exposure * 10000 / (r.liquid_balance + r.outstanding_exposure) >= vp."policy_highThresholdBps"     THEN vp."policy_highFeeBps"
           WHEN r.outstanding_exposure * 10000 / (r.liquid_balance + r.outstanding_exposure) >= vp."policy_midThresholdBps"      THEN vp."policy_midFeeBps"
           ELSE vp."policy_baseFeeBps" END AS fee_bps,
         r.block_number, r.block_timestamp AS "timestamp"
  FROM run r JOIN vault_policy vp ON vp.vault = r.vault;
