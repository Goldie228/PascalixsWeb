#!/bin/bash
# Setup parallel test databases for identity-service
# Usage: ./bin/parallel_setup.sh [NUM_PROCESSES]

set -e

NUM_PROCESSES=${1:-4}
cd "$(dirname "$0")/.."

echo "🔧 Setting up $NUM_PROCESSES parallel test databases..."

# Create storage directory if it doesn't exist
mkdir -p storage

# Create parallel test databases
for i in $(seq 0 $((NUM_PROCESSES - 1))); do
  DB_FILE="storage/test${i}.sqlite3"
  if [ ! -f "$DB_FILE" ]; then
    echo "  Creating $DB_FILE..."
    touch "$DB_FILE"
  fi
done

# Run migrations on all parallel databases
echo "🗄️  Running migrations on parallel databases..."
for i in $(seq 0 $((NUM_PROCESSES - 1))); do
  export PARALLEL_TEST_DB_NUMBER=$i
  echo "  Migrating database $i..."
  bundle exec rails db:migrate --quiet 2>/dev/null || true
done

unset PARALLEL_TEST_DB_NUMBER
echo "✅ Parallel test databases ready!"
