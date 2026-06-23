# Global Flight Network Dashboard, Project Report

**Course:** Graph Databases (KIU, Semester 8)  ·  **Author:** Davit Maisuradze
**Stack:** Neo4j 5 (graph database) + NeoDash 2.4 (dashboard) + Docker + APOC

---

## Contents

1. [Overview](#1-overview)
2. [The data and where it comes from](#2-the-data-and-where-it-comes-from)
3. [Why a graph model](#3-why-a-graph-model)
4. [The graph model](#4-the-graph-model)
5. [Conversion and import pipeline](#5-conversion-and-import-pipeline)
6. [The dashboard, page by page](#6-the-dashboard-page-by-page)
7. [Key Cypher queries](#7-key-cypher-queries)
8. [Design decisions and challenges](#8-design-decisions-and-challenges)
9. [How to run it](#9-how-to-run-it)

---

## 1. Overview

This project loads the global airport network into **Neo4j** and explores it through an interactive **NeoDash** dashboard. Airports become nodes, the routes between them become relationships, and the questions that air travel naturally raises: *which airports are the biggest hubs? how do I get from country A to country B when there is no direct flight? can I fly this whole trip on a single airline?* become short graph traversals.

The finished dashboard has **four pages and 47 reports**, two of which are fully interactive
(driven by dropdown parameters). The headline feature is **automatic route building**: pick
any two countries (or two airports) and the dashboard computes the shortest connecting
itinerary through intermediate airports, even when no direct flight exists: for example
**Georgia → Japan** is built as `TBS → URC → PEK → KIX`.

---

## 2. The data and where it comes from

The dashboard is built on the **OpenFlights** dataset
(<https://github.com/jpatokal/openflights>, published under the Open Database License), a
well-known, community-maintained collection of global aviation data. I used five of its raw
files:

| File | Rows | What it contains |
|------|-----:|------------------|
| `airports.dat`  | 7,698 | Airport id, name, city, country, IATA/ICAO codes, **latitude/longitude**, altitude, timezone |
| `airlines.dat`  | 6,162 | Airline id, name, IATA/ICAO codes, callsign, country, active flag |
| `routes.dat`    | 67,663 | Operating airline + source airport + destination airport + stops + aircraft equipment |
| `countries.dat` | 261 | Country name and ISO code |
| `planes.dat`    | 246 | Aircraft type name + IATA/ICAO code |

I chose flights data because it is a graph where airports are nodes and routes
are edges, so it shows off graph queries (hubs, connectivity, shortest paths) far better
than a relational table would, while staying intuitive enough to present to a non-specialist.

---

## 3. The graph model

**Node types (5):**

* **Airport**: `airportId, name, city, country, iata, icao, latitude, longitude, altitude (meters), location (spatial point)`
* **Airline**: `airlineId, name, iata, icao, callsign, country, active`
* **Country**: `name, isoCode, dafifCode`
* **City**: `key, name, country`
* **Plane**: `iata, icao, name` (aircraft-type lookup, joined to routes by equipment code)

**Relationship types (5):**

* `(:Airport)-[:LOCATED_IN]->(:Country)`
* `(:Airport)-[:IN_CITY]->(:City)`
* `(:City)-[:IN_COUNTRY]->(:Country)`
* `(:Airline)-[:REGISTERED_IN]->(:Country)`
* `(:Airport)-[:ROUTE {airline, airlineId, stops, equipment, distanceKm}]->(:Airport)`, the
  property-rich relationship that carries the operating airline and, crucially, the
  **geographic distance** of the route. There can be **several `ROUTE` edges between the same
  pair of airports** one per operating airline.

---

## 4. Conversion and import pipeline

The raw OpenFlights files are headerless, comma-separated and use `\N` for nulls, so no
manual editing was needed, Neo4j reads them directly with `LOAD CSV`.

1. **`scripts/download_data.sh`** downloads the `.dat` files into `./data`, which is mounted
   into the Neo4j container's import directory.
2. **`docker-compose.yml`** starts Neo4j 5.26 (with the **APOC** plugin) and NeoDash.
3. **`scripts/import.sh`** runs five Cypher scripts (`import/01…05`) in order: constraints and
   indexes, then countries, airports (+cities), airlines, and finally routes.

Two conventions matter throughout the load scripts:

* **Null handling.** Nulls in OpenFlights are the literal string `\N`, so every field is
  guarded with `CASE WHEN row[x] = '\N' THEN null ELSE … END`.
* **Batched writes.** The large loads (airports, routes) use
  `CALL { … } IN TRANSACTIONS` so a single statement commits in batches instead of building
  one giant transaction.
* **Metric units.** OpenFlights reports altitude in feet, so the airport load converts it to
  meters on the way in (`round(toFloat(row[8]) * 0.3048)`); every altitude in the project is
  therefore in meters.

**The most interesting conversion step:** OpenFlights has **no distance or price column**, so
I **compute the great circle distance of every route in Cypher at import time**. Each airport
gets a spatial `point` from its latitude/longitude, and each route stores

```cypher
distanceKm = round(point.distance(src.location, dst.location) / 1000)
```

This single derived property powers the distance histogram, every route/leg table, and all of
the shortest distance routing. Because routes depend on it, the airport `location` points must
exist *before* routes load which is why the import order (01 → 05) is fixed.

---

## 5. The dashboard, page by page

The dashboard is organised into four themed pages. Tables expose **CSV download** and
charts/maps expose **PNG export**.

### Page 1: Airport Network Analysis *(overview)*

A bird's-eye view of the whole network.

* **KPI cards**: total airports, routes, airlines, countries.
* **Bar chart**: top 15 busiest airports by total routes (in + out).
* **Graph**: connection network of the **10 largest hubs** as a node-link diagram.
* **Line chart**: distribution of route distances in 500 km buckets.
* **Pie chart**: top 10 airlines by number of routes.
* **Table** (CSV): full airport-connectivity ranking.
* **Maps**: major airports plotted from coordinates, plus a global airport **density heatmap**.

### Page 2: Country & Route Connectivity *(interactive)*

Pick a **source** and a **destination** country; everything below reacts.

* Two **parameter selectors** (`$neodash_source_country`, `$neodash_destination_country`).
* **KPIs**: number of direct routes between the countries, and the shortest *connecting*
  distance.
* **Bar charts**: top destination countries from the source; top countries by airport count.
* **Table** (CSV): every direct route between the two countries.
* **Connecting-flight map**: the **auto-built shortest itinerary** between the two countries'
  main hubs, drawn on a world map with **numbered stops** (`1 · TBS → 2 · URC → …`). Works
  even when there is no direct flight.
* **Leg-by-leg table** (CSV): each hop of that itinerary: airports, operating airline, distance.
* **Map**: airports of both selected countries.

### Page 3: Aviation Records & Trivia *(extremes)*

The superlatives of the network.

* **Pie chart**: most-used aircraft types (joined to `Plane` nodes; Airbus A320 leads).
* **Tables** (CSV): world's longest non-stop routes (SYD↔DFW, 13,824 km), highest-altitude
  airports (Daocheng Yading, 4,411 m), most isolated airports, and the world's shortest
  scheduled flight (**Papa Westray ↔ Westray, 3 km**).
* **Bar chart**: busiest city-to-city connections.

### Page 4: Airport & Airline Explorer *(interactive trip planner)*

Pick a **From** airport, a **To** airport, and an **airline**. The page builds up in three
layers that make all three selectors work *together*:

1. **From the origin**: a map + table of every destination reachable **non-stop on the
   chosen airline**, and a reachability line chart showing how many airports are reachable
   within 1–4 stops (the *small-world effect*).
2. **From → To, any airline**: a yes/no "Can I fly direct?" card, plus the **best connecting
   itinerary** (shortest distance, numbered map + leg table) that is free to mix airlines.
3. **From → To on one airline**: the headline: a verdict card (*"Emirates: CDG → JFK in 2
   leg(s)"*) plus a numbered map and leg table for the fewest-stop trip flown **entirely on
   the selected carrier**.

The selected airline's full route network (graph + map) is shown at the bottom for context.

---

## 6. Key Cypher queries

These are the queries that do the real work, the ones worth pointing a reader at.

### 6.1 Great-circle distance at import (`import/05_routes.cypher`)

Turns coordinate pairs into a usable weight for every later query:

```cypher
MATCH (src:Airport {airportId: row.srcId}), (dst:Airport {airportId: row.dstId})
CREATE (src)-[:ROUTE {
  airline: row.airline,
  distanceKm: round(point.distance(src.location, dst.location) / 1000)
}]->(dst)
```

### 6.2 Busiest hubs by degree (Page 1)

Counts incoming + outgoing routes per airport using the `COUNT { }` subquery instead of a join:

```cypher
MATCH (a:Airport) WHERE a.iata IS NOT NULL
WITH a, COUNT { (a)-[:ROUTE]->() } + COUNT { (a)<-[:ROUTE]-() } AS routes
RETURN a.iata, routes ORDER BY routes DESC LIMIT 15
```

### 6.3 Country-to-country connecting route: *the flagship* (Page 2)

There is no direct Georgia → Japan flight, so the dashboard builds one. It takes the **top 3
hubs of each country**, runs **Dijkstra weighted by `distanceKm`** between every source/
destination pair, and keeps the cheapest path. Using three hubs per side (not one) makes it
robust for almost any country pair:

```cypher
MATCH (s:Airport)-[:LOCATED_IN]->(:Country {name:$neodash_source_country})
WITH s, COUNT { (s)-[:ROUTE]->() } AS sd WHERE sd > 0
WITH s ORDER BY sd DESC LIMIT 3
WITH collect(s) AS sources
MATCH (d:Airport)-[:LOCATED_IN]->(:Country {name:$neodash_destination_country})
WITH sources, d, COUNT { (d)<-[:ROUTE]-() } AS dd WHERE dd > 0
WITH sources, d ORDER BY dd DESC LIMIT 3
WITH sources, collect(d) AS dests
UNWIND sources AS src
UNWIND dests AS dst
CALL apoc.algo.dijkstra(src, dst, 'ROUTE>', 'distanceKm') YIELD path, weight
RETURN path ORDER BY weight ASC LIMIT 1
```

### 6.4 Numbered stops on the map via virtual nodes (Page 2 & 4)

NeoDash maps can't draw arrowheads, so direction is shown by **numbering the stops**. The path
is rebuilt with **virtual nodes** (`apoc.create.vNode`) whose label carries the stop order,
and **virtual relationships** carrying the leg sequence; these render on the map without
touching the stored graph:

```cypher
WITH nodes(path) AS ns, relationships(path) AS rs
WITH [i IN range(0, size(ns)-1) | apoc.create.vNode(['Airport'], {
       iata: toString(i+1) + ' · ' + ns[i].iata,
       latitude: ns[i].latitude, longitude: ns[i].longitude, location: ns[i].location})] AS vn, rs
UNWIND range(0, size(vn)-2) AS j
RETURN vn[j] AS a,
       apoc.create.vRelationship(vn[j], 'LEG', {seq: j+1, distanceKm: rs[j].distanceKm}, vn[j+1]) AS r,
       vn[j+1] AS b
```

### 6.5 Single-airline routing (Page 4)

*"Can I fly the whole trip on one carrier?"*: `shortestPath` with the airline constraint
pushed into the search as an `all(...)` predicate, so it finds the fewest-stop path and stops
early (sub-second even for hub-heavy airlines):

```cypher
MATCH (al:Airline {name:$neodash_airline}) WITH al.iata AS code LIMIT 1
MATCH (from:Airport {iata:$neodash_from_airport}), (to:Airport {iata:$neodash_to_airport})
MATCH p = shortestPath( (from)-[:ROUTE* 1..4]->(to) )
WHERE all(r IN relationships(p) WHERE r.airline = code)
RETURN p
```

### 6.6 Reachability / small-world effect (Page 4)

`apoc.neighbors.byhop` returns the newly reached airports at each hop; a running sum turns it
into a cumulative reachability curve:

```cypher
MATCH (a:Airport {iata:$neodash_from_airport})
CALL apoc.neighbors.byhop(a, 'ROUTE>', 4) YIELD nodes
WITH collect(size(nodes)) AS perHop
UNWIND range(0, size(perHop)-1) AS i
RETURN (i+1) AS Stops, reduce(s=0, j IN range(0,i) | s + perHop[j]) AS ReachableAirports
ORDER BY Stops
```

---

## 7. Design decisions and challenges

* **Computing distance instead of sourcing it.** The dataset has no distances, so deriving
  `distanceKm` from spatial points (§5) was the key enabler; it is the weight behind every
  Dijkstra and every distance ranking.
* **Top-3 hubs, not one.** An earlier version routed between only the single busiest airport
  of each country and sometimes returned an empty or sub-optimal path. Searching the top three
  hubs per side found shorter, more reliable itineraries (e.g. Georgia → Japan dropped from a
  5-hop, 7,986 km path to a 3-hop, 7,642 km path).
* **`shortestPath` over weighted variable-length for single-airline routing.** The naive
  `(:ROUTE*1..4 {airline})` pattern took **9–13 seconds** for large carriers like Ryanair.
  Rewriting it as `shortestPath` with the constraint as an `all()` predicate lets the planner
  push the filter into a breadth-first search that terminates early, **sub-second** in
  practice.
* **Maps have no arrows.** NeoDash draws map legs as plain lines, so direction is conveyed by
  numbering the stops with virtual nodes (§7.4).
* **Tables vs. charts.** A few reports started as bar/pie charts whose category/value role
  mapping only had one sensible configuration and broke if changed; those were converted to
  tables (which have no such roles) or to pies with the mapping fixed in the dashboard JSON.

---

## 7. How to run it

```bash
bash scripts/download_data.sh     # fetch OpenFlights data into ./data
docker compose up -d              # start Neo4j (+APOC) and NeoDash
bash scripts/import.sh            # load the graph, then print node/edge counts
```

Then open NeoDash at <http://localhost:5005>, connect to `neo4j://localhost:7687`
(user `neo4j`, password `flights123`), and **Load** `dashboard/flights_dashboard.json`.

To reset everything (including the database volume):

```bash
docker compose down -v
```
