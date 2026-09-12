-- The agent's PendingIntents query: intents with no fill on this chain, oldest first.
CREATE VIEW pending_intents AS
  SELECT * FROM intents WHERE fast_status = 'PENDING' ORDER BY created_at_timestamp;
