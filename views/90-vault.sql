-- `vault` singular, kept as the v1 readers' alias for the House Vault row.
CREATE VIEW vault AS
  SELECT * FROM vaults ORDER BY created_at_block, id LIMIT 1;
