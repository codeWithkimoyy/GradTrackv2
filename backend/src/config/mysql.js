let mysql = null;
try {
  mysql = require('mysql2/promise');
} catch (_) {
  // mysql2 will be installed via npm install
}

const host =
  process.env.MYSQL_HOST || process.env.SQL_HOST || 'localhost';
const port = Number.parseInt(
  process.env.MYSQL_PORT || process.env.SQL_PORT || '3306',
  10,
);
const user = process.env.MYSQL_USER || process.env.SQL_USER || 'root';
const password =
  process.env.MYSQL_PASSWORD ?? process.env.SQL_PASS ?? '';
const database =
  process.env.MYSQL_DATABASE || process.env.SQL_DATABASE || 'gradtrack_db';

let pool = null;
let isConnected = false;

if (mysql) {
  try {
    pool = mysql.createPool({
      host,
      port,
      user,
      password,
      database,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      enableKeepAlive: true,
      keepAliveInitialDelay: 0,
    });

    pool
      .getConnection()
      .then((conn) => {
        isConnected = true;
        conn.release();
        console.log(`[MySQL] Connected to database "${database}" on ${host}:${port}`);
      })
      .catch((err) => {
        isConnected = false;
        console.warn(`[MySQL] Connection pending or unavailable: ${err.message}`);
      });
  } catch (err) {
    console.warn(`[MySQL] Pool initialization notice: ${err.message}`);
  }
}

module.exports = {
  pool,
  get isConnected() {
    return isConnected;
  },
  async query(sql, params = []) {
    if (!pool) {
      throw new Error('MySQL connection pool is not initialized.');
    }
    const [rows] = await pool.execute(sql, params);
    return rows;
  },
  /**
   * CALL <proc>(?, ?, ...) helper.
   * Uses pool.query (not execute) so MySQL can return multiple resultsets.
   * Normalizes return value:
   *  - SELECT inside procedure => returns rows array (first resultset)
   *  - UPDATE/INSERT-only procedures => returns OkPacket / affectedRows
   *  - Auto-drains extra resultsets to avoid "commands out of sync"
   */
  async call(procedure, params = []) {
    if (!pool) {
      throw new Error('MySQL connection pool is not initialized.');
    }
    const placeholders = params.map(() => '?').join(', ');
    const sql = `CALL ${procedure}(${placeholders})`;
    const [results] = await pool.query(sql, params);
    // results is typically [ [rows], OkPacket ] for SELECT procedures,
    // or [ OkPacket ] for non-SELECT procedures. Normalize to first rows array.
    if (Array.isArray(results)) {
      // CALL that did SELECT(s): results[0] is rows array
      if (results.length > 0 && Array.isArray(results[0])) {
        return results[0];
      }
      // Non-SELECT: results[0] is OkPacket with affectedRows
      if (results.length > 0 && results[0] && typeof results[0].affectedRows === 'number') {
        return results[0];
      }
      // Single resultset already unwrapped by mysql2 (no nesting)
      return results;
    }
    return results;
  },
  /**
   * Alias that mirrors `call` but keeps legacy naming `callProcedure`.
   */
  async callProcedure(procedure, params = []) {
    return this.call(procedure, params);
  },
  /**
   * Raw CALL that returns all resultsets (useful for procedures returning multiple SELECTs).
   */
  async callRaw(procedure, params = []) {
    if (!pool) {
      throw new Error('MySQL connection pool is not initialized.');
    }
    const placeholders = params.map(() => '?').join(', ');
    const sql = `CALL ${procedure}(${placeholders})`;
    const [results] = await pool.query(sql, params);
    return results;
  },
  async close() {
    if (pool) {
      await pool.end();
      pool = null;
    }
  },
};
