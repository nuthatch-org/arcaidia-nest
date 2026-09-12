-- One row per factory vault: identity, current policy, folded balances, and the fee the policy
-- ladder implies at the current utilisation.
--
-- utilisation_bps is derived, not read from the contract: outstanding exposure as a share of the
-- vault's total capital, exposure * 10000 / (liquid + exposure), zero when the vault is empty.
-- current_fee_bps walks the four tiers with `>=`, as fee-policy.ts does.
CREATE VIEW vaults AS
  SELECT vp.vault AS id,
         vp.owner,
         vp.label,
         vp.created_at_block,
         vp.created_at_timestamp,
         vp."policy_baseFeeBps", vp."policy_midFeeBps", vp."policy_highFeeBps", vp."policy_criticalFeeBps",
         vp."policy_midThresholdBps", vp."policy_highThresholdBps", vp."policy_criticalThresholdBps",
         vp.reserve_floor_bps, vp.max_fill_bps, vp.max_exposure_bps,
         vf.liquid_balance, vf.outstanding_exposure, vf.accrued_protocol_fees,
         CASE WHEN vf.liquid_balance + vf.outstanding_exposure > 0
              THEN CAST(vf.outstanding_exposure * 10000 / (vf.liquid_balance + vf.outstanding_exposure) AS BIGINT)
              ELSE 0 END AS utilisation_bps,
         CASE
           WHEN vf.liquid_balance + vf.outstanding_exposure <= 0 THEN vp."policy_baseFeeBps"
           WHEN vf.outstanding_exposure * 10000 / (vf.liquid_balance + vf.outstanding_exposure) >= vp."policy_criticalThresholdBps" THEN vp."policy_criticalFeeBps"
           WHEN vf.outstanding_exposure * 10000 / (vf.liquid_balance + vf.outstanding_exposure) >= vp."policy_highThresholdBps"     THEN vp."policy_highFeeBps"
           WHEN vf.outstanding_exposure * 10000 / (vf.liquid_balance + vf.outstanding_exposure) >= vp."policy_midThresholdBps"      THEN vp."policy_midFeeBps"
           ELSE vp."policy_baseFeeBps" END AS current_fee_bps,
         vf.fill_count, vf.total_fees_earned, vf.total_deposited, vf.total_withdrawn,
         vf.paused, vf.updated_at_block, vf.updated_at_timestamp
  FROM vault_policy vp JOIN vault_flows vf ON vf.vault = vp.vault;
