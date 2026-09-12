'use strict';

const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Liara/managed Postgres usually terminates TLS at the proxy; keep it off by
  // default and let DATABASE_URL include sslmode when needed.
});

/** Run a query and return the result. */
function query(text, params) {
  return pool.query(text, params);
}

/** Run a callback inside a transaction. */
async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, withTransaction };
