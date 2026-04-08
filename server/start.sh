#!/bin/sh
set -e

echo "Running database migrations..."
migration_exit=0
timeout 120 npx prisma migrate deploy || migration_exit=$?

if [ "$migration_exit" -eq 124 ]; then
  echo "ERROR: 'prisma migrate deploy' timed out after 120 seconds." >&2
  exit 1
elif [ "$migration_exit" -ne 0 ]; then
  echo "ERROR: 'prisma migrate deploy' failed with exit code $migration_exit." >&2
  exit 1
fi

echo "Migrations completed."
echo "Starting server..."
exec node dist/server.js
