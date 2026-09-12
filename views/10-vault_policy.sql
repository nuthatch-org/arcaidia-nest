-- Each vault's current fee policy and caps. The factory emits them at creation; the vault can
-- change them afterwards (FeePolicyConfigured, FillLimitsConfigured, ReserveFloorConfigured), so
-- the current value is the latest of those, falling back to the creation value.
-- `policy` is a uint16[7] tuple, which decodes to a JSON array of strings, hence the extracts.
CREATE VIEW vault_policy AS
  WITH created AS (
    SELECT vault,
           owner,
           label,
           block_number    AS created_at_block,
           block_timestamp AS created_at_timestamp,
           CAST(json_extract_string(policy, '$[0]') AS BIGINT) AS base_fee_bps,
           CAST(json_extract_string(policy, '$[1]') AS BIGINT) AS mid_fee_bps,
           CAST(json_extract_string(policy, '$[2]') AS BIGINT) AS high_fee_bps,
           CAST(json_extract_string(policy, '$[3]') AS BIGINT) AS critical_fee_bps,
           CAST(json_extract_string(policy, '$[4]') AS BIGINT) AS mid_threshold_bps,
           CAST(json_extract_string(policy, '$[5]') AS BIGINT) AS high_threshold_bps,
           CAST(json_extract_string(policy, '$[6]') AS BIGINT) AS critical_threshold_bps,
           "reserveFloorBps" AS reserve_floor_bps,
           "maxFillBps"      AS max_fill_bps,
           "maxExposureBps"  AS max_exposure_bps
    FROM "vault_factory__vault_created"
  ),
  repolicy AS (
    SELECT address AS vault,
           arg_max(CAST(json_extract_string(policy, '$[0]') AS BIGINT), block_number * 1000000 + log_index) AS base_fee_bps,
           arg_max(CAST(json_extract_string(policy, '$[1]') AS BIGINT), block_number * 1000000 + log_index) AS mid_fee_bps,
           arg_max(CAST(json_extract_string(policy, '$[2]') AS BIGINT), block_number * 1000000 + log_index) AS high_fee_bps,
           arg_max(CAST(json_extract_string(policy, '$[3]') AS BIGINT), block_number * 1000000 + log_index) AS critical_fee_bps,
           arg_max(CAST(json_extract_string(policy, '$[4]') AS BIGINT), block_number * 1000000 + log_index) AS mid_threshold_bps,
           arg_max(CAST(json_extract_string(policy, '$[5]') AS BIGINT), block_number * 1000000 + log_index) AS high_threshold_bps,
           arg_max(CAST(json_extract_string(policy, '$[6]') AS BIGINT), block_number * 1000000 + log_index) AS critical_threshold_bps
    FROM "liquidity_vault__fee_policy_configured" GROUP BY address
  ),
  relimits AS (
    SELECT address AS vault,
           arg_max("maxFillBps",     block_number * 1000000 + log_index) AS max_fill_bps,
           arg_max("maxExposureBps", block_number * 1000000 + log_index) AS max_exposure_bps
    FROM "liquidity_vault__fill_limits_configured" GROUP BY address
  ),
  refloor AS (
    SELECT address AS vault,
           arg_max("reserveFloorBps", block_number * 1000000 + log_index) AS reserve_floor_bps
    FROM "liquidity_vault__reserve_floor_configured" GROUP BY address
  )
  SELECT c.vault, c.owner, c.label, c.created_at_block, c.created_at_timestamp,
         coalesce(p.base_fee_bps,           c.base_fee_bps)           AS "policy_baseFeeBps",
         coalesce(p.mid_fee_bps,            c.mid_fee_bps)            AS "policy_midFeeBps",
         coalesce(p.high_fee_bps,           c.high_fee_bps)           AS "policy_highFeeBps",
         coalesce(p.critical_fee_bps,       c.critical_fee_bps)       AS "policy_criticalFeeBps",
         coalesce(p.mid_threshold_bps,      c.mid_threshold_bps)      AS "policy_midThresholdBps",
         coalesce(p.high_threshold_bps,     c.high_threshold_bps)     AS "policy_highThresholdBps",
         coalesce(p.critical_threshold_bps, c.critical_threshold_bps) AS "policy_criticalThresholdBps",
         coalesce(f.reserve_floor_bps, c.reserve_floor_bps) AS reserve_floor_bps,
         coalesce(l.max_fill_bps,      c.max_fill_bps)      AS max_fill_bps,
         coalesce(l.max_exposure_bps,  c.max_exposure_bps)  AS max_exposure_bps
  FROM created c
  LEFT JOIN repolicy p ON p.vault = c.vault
  LEFT JOIN relimits l ON l.vault = c.vault
  LEFT JOIN refloor  f ON f.vault = c.vault;
