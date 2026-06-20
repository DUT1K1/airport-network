#!/usr/bin/env bash
# Download the OpenFlights raw data files into ./data so Neo4j can LOAD CSV them.
# Source: https://github.com/jpatokal/openflights (Open Database License)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/../data"
BASE="https://raw.githubusercontent.com/jpatokal/openflights/master/data"

mkdir -p "$DATA_DIR"

for f in airports.dat airlines.dat routes.dat countries.dat planes.dat; do
  echo "Downloading $f ..."
  curl -fsSL "$BASE/$f" -o "$DATA_DIR/$f"
done

echo
echo "Done. Files saved to: $DATA_DIR"
ls -lh "$DATA_DIR"
echo
echo "Row counts:"
wc -l "$DATA_DIR"/*.dat
