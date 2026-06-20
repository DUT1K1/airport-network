// Plane (aircraft type) lookup nodes, joined to routes via the ROUTE.equipment IATA code(s).
// planes.dat columns: 0=name, 1=IATA, 2=ICAO
CREATE INDEX plane_iata IF NOT EXISTS FOR (p:Plane) ON (p.iata);
LOAD CSV FROM 'file:///planes.dat' AS row
WITH row WHERE row[1] <> '\N' AND row[1] <> ''
MERGE (p:Plane {iata: row[1]})
SET p.name = row[0],
    p.icao = CASE WHEN row[2] = '\N' OR row[2] = '' THEN null ELSE row[2] END;
