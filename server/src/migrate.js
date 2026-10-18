'use strict';

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./db');

/**
 * Applies sql/schema.sql (the base, idempotent schema) followed by every file
 * in sql/migrations, in filename order. Every migration is written to be safe
 * to run repeatedly (CREATE ... IF NOT EXISTS), so this is a converge-to-latest
 * operation rather than a one-shot stamp.
 */
async function main() {
  const basePath = path.join(__dirname, '..', 'sql', 'schema.sql');
  await pool.query(fs.readFileSync(basePath, 'utf8'));
  console.log('Base schema applied (sql/schema.sql).');

  const migrationsDir = path.join(__dirname, '..', 'sql', 'migrations');
  if (fs.existsSync(migrationsDir)) {
    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();
    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      await pool.query(sql);
      console.log(`Migration applied: ${file}`);
    }
  }
  console.log('Migrations complete.');
  await pool.end();
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
