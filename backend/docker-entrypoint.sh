#!/bin/sh
set -e
echo "[entrypoint] Running database migrations..."
npx prisma db push --accept-data-loss
echo "[entrypoint] Starting server..."
exec node dist/index.js
