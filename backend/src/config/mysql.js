let mysql = null;
try {
  mysql = require('mysql2/promise');
} catch (_) {
  // mysql2 will be installed via npm install
}

const host = process.env.MYSQL_HOST || 'localhost';
const port = Number.parseInt(process.env.MYSQL_PORT || '3306', 10);
const user = process.env.MYSQL_USER || 'root';
const password = process.env.MYSQL_PASSWORD || '';
const database = process.env.MYSQL_DATABASE || 'gradtrack_db';

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
};
