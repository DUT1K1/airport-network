#!/usr/bin/env bash
# Run all Cypher import scripts inside the running Neo4j container, in order.
# Prereq:  docker compose up -d   AND   bash scripts/download_data.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPORT_DIR="$SCRIPT_DIR/../import"
CONTAINER="flights-neo4j"
USER="neo4j"
PASS="flights123"

echo "Waiting for Neo4j to accept connections ..."
until docker exec "$CONTAINER" cypher-shell -u "$USER" -p "$PASS" "RETURN 1;" >/dev/null 2>&1; do
  sleep 3
  echo "  ... still waiting"
done
echo "Neo4j is up."

for f in 01_constraints 02_countries 03_airports 04_airlines 05_routes 06_planes; do
  echo
  echo "==> Running $f.cypher"
  docker exec -i "$CONTAINER" cypher-shell -u "$USER" -p "$PASS" --format plain < "$IMPORT_DIR/$f.cypher"
done

echo
echo "==> Import summary"
docker exec -i "$CONTAINER" cypher-shell -u "$USER" -p "$PASS" --format plain <<'CYPHER'
MATCH (a:Airport)  WITH count(a) AS airports
MATCH (al:Airline) WITH airports, count(al) AS airlines
MATCH (c:Country)  WITH airports, airlines, count(c) AS countries
MATCH (ci:City)    WITH airports, airlines, countries, count(ci) AS cities
MATCH (p:Plane)    WITH airports, airlines, countries, cities, count(p) AS planes
MATCH ()-[r:ROUTE]->() RETURN airports, airlines, countries, cities, planes, count(r) AS routes;
CYPHER

echo
echo "Done. Open Neo4j Browser at http://localhost:7474  (neo4j / flights123)"
echo "Open NeoDash at        http://localhost:5005  then Load dashboard from dashboard/flights_dashboard.json"
