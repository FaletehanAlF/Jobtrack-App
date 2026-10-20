
import express from "express";
import type { NextFunction, Request, Response } from "express";
import cors from "cors";
import helmet from "helmet";
import { authRouter } from "./routes/auth.routes.js";

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());

app.get("/", (_req, res) => {
  res.json({
    message: "JobTrack API is running",
  });
});

app.use("/api/auth", authRouter);

app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  console.error("[error]", error);
  if (res.headersSent) return;
  res.status(500).json({ message: "Terjadi kesalahan pada server" });
});

export default app;
