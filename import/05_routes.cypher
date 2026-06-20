// ROUTE relationships between airports — the property-rich relationship.
// routes.dat columns:
//   0=airline_code 1=airline_id 2=src_iata 3=src_airport_id
//   4=dst_iata 5=dst_airport_id 6=codeshare 7=stops 8=equipment
// distanceKm is computed from the two airports' geographic points.
LOAD CSV FROM 'file:///routes.dat' AS row
CALL {
  WITH row
  WITH row WHERE row[3] <> '\N' AND row[5] <> '\N'
  MATCH (src:Airport {airportId: toInteger(row[3])})
  MATCH (dst:Airport {airportId: toInteger(row[5])})
  MERGE (src)-[r:ROUTE {airline: row[0]}]->(dst)
  SET r.airlineId  = CASE WHEN row[1] = '\N' OR row[1] = '' THEN null ELSE toInteger(row[1]) END,
      r.stops      = toInteger(row[7]),
      r.equipment  = CASE WHEN row[8] = '\N' OR row[8] = '' THEN null ELSE row[8] END,
      r.distanceKm = toInteger(round(point.distance(src.location, dst.location) / 1000.0))
} IN TRANSACTIONS OF 2000 ROWS;
