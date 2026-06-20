// Airport nodes + City nodes + LOCATED_IN / IN_CITY / IN_COUNTRY relationships.
// airports.dat columns:
//   0=id 1=name 2=city 3=country 4=IATA 5=ICAO 6=lat 7=lon 8=altitude
//   9=tz_offset 10=dst 11=tz_database 12=type 13=source
LOAD CSV FROM 'file:///airports.dat' AS row
CALL {
  WITH row
  // need valid coordinates so we can build a spatial point + compute distances
  WITH row WHERE row[6] <> '\N' AND row[7] <> '\N'
  MERGE (a:Airport {airportId: toInteger(row[0])})
  SET a.name      = row[1],
      a.city      = CASE WHEN row[2] = '\N' OR row[2] = '' THEN null ELSE row[2] END,
      a.country   = row[3],
      a.iata      = CASE WHEN row[4] = '\N' OR row[4] = '' OR row[4] = '\\N' THEN null ELSE row[4] END,
      a.icao      = CASE WHEN row[5] = '\N' OR row[5] = '' THEN null ELSE row[5] END,
      a.latitude  = toFloat(row[6]),
      a.longitude = toFloat(row[7]),
      a.altitude  = toFloat(row[8]),
      a.timezone  = CASE WHEN row[11] = '\N' THEN null ELSE row[11] END,
      a.type      = row[12],
      a.location  = point({latitude: toFloat(row[6]), longitude: toFloat(row[7])})
  MERGE (co:Country {name: row[3]})
  MERGE (a)-[:LOCATED_IN]->(co)
  // City node only when the airport actually lists a city
  WITH a, co, row WHERE row[2] <> '\N' AND row[2] <> ''
  MERGE (city:City {key: row[2] + '|' + row[3]})
    ON CREATE SET city.name = row[2], city.country = row[3]
  MERGE (a)-[:IN_CITY]->(city)
  MERGE (city)-[:IN_COUNTRY]->(co)
} IN TRANSACTIONS OF 1000 ROWS;
