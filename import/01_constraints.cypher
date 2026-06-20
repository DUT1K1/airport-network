// Uniqueness constraints (each also creates a backing index used by the loads below)
CREATE CONSTRAINT airport_id   IF NOT EXISTS FOR (a:Airport) REQUIRE a.airportId IS UNIQUE;
CREATE CONSTRAINT airline_id   IF NOT EXISTS FOR (a:Airline) REQUIRE a.airlineId IS UNIQUE;
CREATE CONSTRAINT country_name IF NOT EXISTS FOR (c:Country) REQUIRE c.name      IS UNIQUE;
CREATE CONSTRAINT city_key     IF NOT EXISTS FOR (c:City)    REQUIRE c.key       IS UNIQUE;

// Secondary indexes for fast lookups / joins used by the dashboard queries
CREATE INDEX airport_iata IF NOT EXISTS FOR (a:Airport) ON (a.iata);
CREATE INDEX airline_iata IF NOT EXISTS FOR (a:Airline) ON (a.iata);
