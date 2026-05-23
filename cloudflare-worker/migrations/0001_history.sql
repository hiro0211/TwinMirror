CREATE TABLE IF NOT EXISTS history (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER,
  gender TEXT,
  age TEXT,
  mode TEXT,
  style TEXT,
  ratio TEXT,
  prompt TEXT,
  r2_key TEXT NOT NULL,
  thumb_r2_key TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_history_device_time
  ON history (device_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_history_expires
  ON history (expires_at);
