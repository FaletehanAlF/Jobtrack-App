
import { db } from "./config/database.js";

async function testConnection() {
  try {
    const connection = await db.getConnection();
    console.log("Koneksi MySQL berhasil!");
    connection.release();
  } catch (error) {
    console.error("Koneksi MySQL gagal:", error);
  } finally {
    await db.end();
  }
}

testConnection();
