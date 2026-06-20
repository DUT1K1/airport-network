# Global Flight Network Dashboard — Project Report

**Course:** Graph Databases (KIU, Semester 8) · **Author:** David Maisuradze
**Stack:** Neo4j 5 (graph database) + NeoDash 2.4 (dashboard) + Docker

## 1. What the data is and where it comes from

The dashboard is built on the **OpenFlights** dataset
(<https://github.com/jpatokal/openflights>, published under the Open Database License).
OpenFlights is a well-known, community-maintained collection of global civil-aviation
data. I used four of its raw files:

| File | Rows | What it contains |
|------|-----:|------------------|
| `airports.dat`  | 7,698 | Airport id, name, city, country, IATA/ICAO codes, **latitude/longitude**, altitude, timezone |
| `airlines.dat`  | 6,162 | Airline id, name, IATA/ICAO codes, callsign, country, active flag |
| `routes.dat`    | 67,663 | Airline + source airport + destination airport + stops + aircraft equipment |
| `countries.dat` | 261 | Country name and ISO code |
| `planes.dat`    | 246 | Aircraft type name + IATA/ICAO code |

I chose flights data because it is naturally a **graph** — airports are nodes and routes
are the edges between them — so it shows off graph queries (hubs, connectivity, shortest
paths) far better than a relational table would. It is also intuitive and easy to present.

## 2. Why a graph model

Air travel is a network problem. Questions like *"which airports are the biggest hubs?"*,
*"how do I get from country A to country B?"* and *"what is the shortest-distance route?"*
are graph-traversal questions. Modelling routes as relationships lets me answer them with
short Cypher queries (degree counting, `shortestPath`, Dijkstra) instead of expensive joins.

## 3. The graph model

**Node types (5):**

* **Airport** — `airportId, name, city, country, iata, icao, latitude, longitude, altitude, location (spatial point)`
* **Airline** — `airlineId, name, iata, icao, callsign, country, active`
* **Country** — `name, isoCode, dafifCode`
* **City** — `key, name, country`
* **Plane** — `iata, icao, name` (aircraft-type lookup, joined to routes by equipment code)

**Relationship types (5):**

* `(:Airport)-[:LOCATED_IN]->(:Country)`
* `(:Airport)-[:IN_CITY]->(:City)`
* `(:City)-[:IN_COUNTRY]->(:Country)`
* `(:Airline)-[:REGISTERED_IN]->(:Country)`
* `(:Airport)-[:ROUTE {airline, airlineId, stops, equipment, distanceKm}]->(:Airport)` — the
  property-rich relationship that carries the operating airline and, crucially, the
  **geographic distance** of the route.

After import the database holds **7,698 airports, 6,161 airlines, 355 countries,
7,095 cities, 220 aircraft types and 66,771 routes**.

## 4. How the data was converted and imported

The raw OpenFlights files are headerless, comma-separated and use `\N` for nulls, so no
manual editing was needed — Neo4j reads them directly.

1. `scripts/download_data.sh` downloads the five `.dat` files into `./data`, which is mounted
   into the Neo4j container's import directory.
2. `docker-compose.yml` starts Neo4j 5.26 (with the APOC plugin) and NeoDash.
3. `scripts/import.sh` runs five Cypher scripts with `LOAD CSV` (`import/01…05`): constraints
   and indexes, then countries, airports (+cities), airlines, and finally routes.

The most interesting conversion step: OpenFlights has **no distance or price column**, so I
**compute the great-circle distance of every route in Cypher**. Each airport gets a spatial
`point` from its latitude/longitude, and each route stores
`distanceKm = round(point.distance(src.location, dst.location)/1000)`. This single derived
property powers the distance histogram, the route tables, and the shortest-distance routing.

## 5. What is in the dashboard

The dashboard has **four pages** (41 reports total), grouped by topic, each with relevant
titles.

**Page 1 — Airport Network Analysis**
* KPI cards: total airports, routes, airlines, countries.
* **Bar chart** — top 15 busiest airports by total routes.
* **Graph** — connection network of the 12 largest hubs (node-link diagram).
* **Line chart** — distribution of route distances in 500 km buckets.
* **Pie chart** — top 10 airlines by number of routes.
* **Table** (downloadable CSV) — full airport-connectivity ranking.
* **Map** — major airports plotted from coordinates, plus a global **density heatmap**.

**Page 2 — Country & Route Connectivity** (interactive)
* Two **input parameters**: a *source* and a *destination* country selector.
* KPIs: number of direct routes between them, and the shortest-path distance.
* **Bar charts** — top destination countries from the source; top countries by airports.
* **Table** (downloadable CSV) — every direct route between the two countries.
* **Graph** — the **shortest-distance flight path** between the countries' main hubs,
  computed with `apoc.algo.dijkstra` weighted by `distanceKm` (handles multi-hop trips, e.g.
  Iceland→Fiji via KEF→YEG→YVR→HNL→NAN).
* **Graph** — country-to-country connectivity network built with virtual relationships.
* **Map** — airports of both selected countries.

**Page 3 — Aviation Records & Trivia**
* **Bar charts** — longest non-stop routes; busiest city-to-city connections.
* **Pie chart** — most-used aircraft types (joining routes to the Plane nodes).
* **Tables** (downloadable CSV) — highest-altitude airports, most isolated airports, and the
  world's shortest scheduled flights (Westray↔Papa Westray, 3 km).

**Page 4 — Airport & Airline Explorer** (interactive)
* Three **input parameters**: *From* airport, *To* airport, and an airline.
* **Map + table** — "Where can I fly from here?": every direct destination of the chosen
  airport, with distances.
* **Single value** — "Can I fly direct?" yes/no between the two chosen airports, plus a detail
  table.
* **Line chart** — reachability curve: airports reachable within 1–4 stops
  (`apoc.neighbors.byhop`), illustrating the small-world effect.
* **Graph + map** — the full route network of the chosen airline.

**Downloads:** tables expose CSV download, and charts/graphs/maps expose PNG image export.

## 6. How to run it

```bash
bash scripts/download_data.sh     # fetch OpenFlights data
docker compose up -d              # start Neo4j + NeoDash
bash scripts/import.sh            # load the graph
```

Then open NeoDash at <http://localhost:5005>, connect to `neo4j://localhost:7687`
(user `neo4j`, password `flights123`), and **Load** `dashboard/flights_dashboard.json`.
