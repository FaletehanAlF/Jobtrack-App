import express from "express";
import type { NextFunction, Request, Response } from "express";
import dotenv from "dotenv";
import jwt from "jsonwebtoken";
import { authenticate } from "./src/middleware/auth.middleware.js";

dotenv.config();

let handlerCalls = 0;

const app = express();

// Rute uji: hanya bisa diakses jika middleware meloloskan request.
app.get("/protected", authenticate, (req: Request, res: Response) => {
  handlerCalls++;
  res.json({ message: "masuk", user: req.user });
});

// Error handler, supaya error JWT_SECRET kosong terlihat sebagai 500 JSON.
app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  res.status(500).json({ message: "error server", detail: String(error) });
});

const secret = process.env.JWT_SECRET;
if (!secret) {
  console.error("JWT_SECRET tidak ada di .env — tes tidak bisa jalan");
  process.exit(1);
}

const server = app.listen(6100, async () => {
  const base = "http://localhost:6100/protected";

  async function call(label: string, headers: Record<string, string>) {
    const before = handlerCalls;
    const res = await fetch(base, { headers });
    const body = await res.text();
    const reached = handlerCalls > before;
    console.log(
      `${label.padEnd(42)} status=${res.status}  handler_dipanggil=${reached}  ${body.slice(0, 90)}`,
    );
  }

  const validToken = jwt.sign({ id: 7, role: "jobseeker" }, secret, {
    expiresIn: "7d",
  });

  await call("1) tanpa header Authorization", {});
  await call("2) format salah (tanpa Bearer)", {
    Authorization: validToken,
  });
  await call("3) Bearer tanpa token", { Authorization: "Bearer " });
  await call("4) token rusak", { Authorization: "Bearer abc.def.ghi" });
  await call("5) token ditandatangani secret salah", {
    Authorization: `Bearer ${jwt.sign({ id: 7, role: "jobseeker" }, "secret-palsu")}`,
  });
  await call("6) token kedaluwarsa", {
    Authorization: `Bearer ${jwt.sign({ id: 7, role: "jobseeker" }, secret, { expiresIn: "-10s" })}`,
  });
  await call("7) payload tanpa id/role", {
    Authorization: `Bearer ${jwt.sign({ foo: "bar" }, secret)}`,
  });
  await call("8) token VALID", { Authorization: `Bearer ${validToken}` });
  await call("9) scheme huruf kecil 'bearer'", {
    Authorization: `bearer ${validToken}`,
  });

  // 10) JWT_SECRET dihapus sementara: harus gagal tertutup (500), bukan lolos.
  const saved = process.env.JWT_SECRET;
  delete process.env.JWT_SECRET;
  await call("10) JWT_SECRET kosong (fail closed)", {
    Authorization: `Bearer ${validToken}`,
  });
  process.env.JWT_SECRET = saved;

  console.log(`\nTotal pemanggilan handler: ${handlerCalls} (harus 3: tes 8, 9, dan tidak ada yang lain)`);

  server.close();
});
