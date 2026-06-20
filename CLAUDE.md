# CLAUDE.md

Guidance for AI assistants (and humans) working in this repository.

## What this is

A **graph-database dashboard** course project (KIU — Graph Databases). It loads the
[OpenFlights](https://github.com/jpatokal/openflights) dataset into **Neo4j 5** and visualises
it with **NeoDash 2.4**. There is no application code to compile — the project is data +
Cypher import scripts + a declarative NeoDash dashboard (JSON) + a written report.

## Architecture / data flow

```
OpenFlights .dat files  ──download_data.sh──▶  ./data/  ──(mounted)──▶  Neo4j import dir
                                                                              │
                          import/01..05.cypher  ──import.sh (cypher-shell)────┘
                                                                              ▼
                                                                      Neo4j graph
                                                                              ▲
                                              browser bolt (localhost:7687)   │
        NeoDash (localhost:5005) ◀── Load dashboard/flights_dashboard.json ───┘
```

- **Neo4j** and **NeoDash** run as Docker containers (`docker-compose.yml`).
- NeoDash runs in the browser and talks to Neo4j over **bolt at `localhost:7687`** (the
  connection is made from the user's browser, not container-to-container).
- Credentials are `neo4j` / `flights123` (set via `NEO4J_AUTH`).

## Common commands

```bash
bash scripts/download_data.sh    # fetch OpenFlights .dat files into ./data
docker compose up -d             # start Neo4j (+APOC) and NeoDash
bash scripts/import.sh           # wait for Neo4j, run import/01..05, print counts
docker compose down -v           # stop and wipe the DB volume (full reset)

# Run an ad-hoc query:
docker exec -i flights-neo4j cypher-shell -u neo4j -p flights123 --format plain <<'EOF'
MATCH (a:Airport) RETURN count(a);
EOF
```

## Graph model (the contract every query depends on)

**Nodes:** `Airport` (airportId, name, city, country, iata, icao, latitude, longitude,
altitude, `location` spatial point), `Airline` (airlineId, name, iata, icao, callsign,
country, active), `Country` (name, isoCode, dafifCode), `City` (key, name, country).

**Relationships:**
- `(:Airport)-[:LOCATED_IN]->(:Country)`
- `(:Airport)-[:IN_CITY]->(:City)` and `(:City)-[:IN_COUNTRY]->(:Country)`
- `(:Airline)-[:REGISTERED_IN]->(:Country)`
- `(:Airport)-[:ROUTE {airline, airlineId, stops, equipment, distanceKm}]->(:Airport)`
  — the property-rich relationship; can be **multiple** between the same airport pair
  (one per operating airline).

Loaded scale: ~7.7k airports, ~6.2k airlines, 355 countries, ~7.1k cities, ~66.8k routes.

## Important conventions & gotchas

- **`distanceKm` is computed, not sourced.** OpenFlights has no distance/price column.
  `import/05_routes.cypher` sets `distanceKm = round(point.distance(src.location, dst.location)/1000)`.
  Airport `location` points must therefore be set *before* routes load — keep the import order
  01→05.
- **Nulls in the data are the literal string `\N`** (and sometimes `""`/`-`). Every load script
  guards against these with `CASE WHEN row[x]='\N' ...`. Reuse that pattern for new fields.
- **Routes join to airports by airport ID** (`routes.dat` cols 3 & 5), not by IATA code.
  Routes join to airlines via `r.airline = al.iata`.
- **Large loads use `CALL { ... } IN TRANSACTIONS`** (airports, routes) to batch-commit.
  Run them as single statements via `cypher-shell` (autocommit), not inside an open txn.
- **Apple Silicon:** NeoDash image is amd64-only → `platform: linux/amd64` is pinned in compose.
- **Shortest-distance routing** uses `apoc.algo.dijkstra(src, dst, 'ROUTE>', 'distanceKm')`
  (note the `>` for direction). APOC is enabled via `NEO4J_PLUGINS: '["apoc"]'`.

## The dashboard (`dashboard/flights_dashboard.json`)

NeoDash **2.4** schema. Two pages:
1. **Airport Network Analysis** — KPI values, busiest-airports bar, hub-network graph,
   route-distance line, airlines pie, connectivity table (CSV), world map.
2. **Country & Route Connectivity** — two country `select` parameters
   (`$neodash_source_country`, `$neodash_destination_country`), direct-routes table (CSV),
   shortest-distance path graph (Dijkstra), maps and bars.

When editing the JSON: each report needs a unique `id`, a `type` from NeoDash's allowed set
(`table`, `graph`, `bar`, `line`, `pie`, `map`, `value`, `text`, `select`), a `selection`
mapping result columns to roles, and grid coords (`x`,`y`,`width`,`height`; canvas is 24
columns wide, rows are 100px). **Validate any change with**
`python3 -c "import json;json.load(open('dashboard/flights_dashboard.json'))"` and re-load it
in NeoDash — a malformed file fails silently to import.

## Report

`report/REPORT.md` is the source; `report/REPORT.html` is print-ready. Submission PDF is made
by opening the HTML in a browser and Save-as-PDF (no PDF toolchain is installed locally).
