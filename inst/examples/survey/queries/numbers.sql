-- Bind the lower bound through the connection's DBI driver.
SELECT amount FROM numbers WHERE amount > ? ORDER BY amount
