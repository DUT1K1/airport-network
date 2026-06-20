// Country nodes  (name, isoCode, dafifCode)
// countries.dat columns: 0=name, 1=iso_code, 2=dafif_code
LOAD CSV FROM 'file:///countries.dat' AS row
WITH row WHERE row[0] IS NOT NULL AND row[0] <> '\N' AND row[0] <> ''
MERGE (c:Country {name: row[0]})
SET c.isoCode   = CASE WHEN row[1] = '\N' OR row[1] = '' THEN null ELSE row[1] END,
    c.dafifCode = CASE WHEN row[2] = '\N' OR row[2] = '' THEN null ELSE row[2] END;
