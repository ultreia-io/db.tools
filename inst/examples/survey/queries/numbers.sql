-- Bind the lower bound through the connection's DBI driver.
SELECT value FROM numbers WHERE value > ? ORDER BY value
