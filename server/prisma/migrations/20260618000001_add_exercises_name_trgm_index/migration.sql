-- Enable the pg_trgm extension so PostgreSQL can build a GIN trigram index.
-- Required for ILIKE '%pattern%' queries (leading wildcard) to use an index
-- instead of a full sequential scan. Safe to run multiple times.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GIN trigram index on exercises.name. Speeds up every ILIKE '%squat%' /
-- '%bench press%' / '%deadlift%' query in the strength score history and
-- overview endpoints, which each run 3+ ILIKE filters per request.
CREATE INDEX IF NOT EXISTS idx_exercises_name_trgm
  ON exercises USING GIN (name gin_trgm_ops);
