// Airline nodes + REGISTERED_IN relationship to Country.
// airlines.dat columns:
//   0=id 1=name 2=alias 3=IATA 4=ICAO 5=callsign 6=country 7=active(Y/N)
LOAD CSV FROM 'file:///airlines.dat' AS row
WITH row WHERE toInteger(row[0]) > 0          // skip the "-1 / Unknown" placeholder row
MERGE (al:Airline {airlineId: toInteger(row[0])})
SET al.name     = row[1],
    al.alias    = CASE WHEN row[2] = '\N' OR row[2] = '' THEN null ELSE row[2] END,
    al.iata     = CASE WHEN row[3] = '\N' OR row[3] = '' OR row[3] = '-' THEN null ELSE row[3] END,
    al.icao     = CASE WHEN row[4] = '\N' OR row[4] = '' OR row[4] = 'N/A' THEN null ELSE row[4] END,
    al.callsign = CASE WHEN row[5] = '\N' OR row[5] = '' THEN null ELSE row[5] END,
    al.country  = CASE WHEN row[6] = '\N' OR row[6] = '' THEN null ELSE row[6] END,
    al.active   = (row[7] = 'Y')
WITH al, row WHERE row[6] <> '\N' AND row[6] <> ''
MERGE (co:Country {name: row[6]})
MERGE (al)-[:REGISTERED_IN]->(co);
