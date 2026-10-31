
import express from "express";
import type { NextFunction, Request, Response } from "express";
import cors from "cors";
import helmet from "helmet";
import { authRouter } from "./routes/auth.routes.js";
import { jobRouter } from "./routes/job.routes.js";
import { applicationRouter } from "./routes/application.routes.js";
import { recruiterRouter } from "./routes/recruiter.routes.js";
import { notificationRouter } from "./routes/notification.routes.js";

const app = express();

app.use(helmet());
app.use(cors({ exposedHeaders: ["Content-Disposition"] }));
app.use(express.json());

app.get("/", (_req, res) => {
  res.json({
    message: "JobTrack API is running",
  });
});

app.use("/api/auth", authRouter);
app.use("/api/jobs", jobRouter);
app.use("/api/applications", applicationRouter);
app.use("/api/recruiter", recruiterRouter);
app.use("/api/notifications", notificationRouter);

// Penanda yang dipakai express.json() saat body JSON tidak bisa di-parse.
function isJsonParseError(error: unknown): boolean {
  if (!(error instanceof SyntaxError)) return false;
  // Cek properti type, bukan hanya instanceof SyntaxError, supaya SyntaxError
  // lain di dalam aplikasi tidak salah dianggap kesalahan input klien.
  const parseError = error as SyntaxError & { type?: string };
  return parseError.type === "entity.parse.failed";
}

app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  console.error("[error]", error);
  if (res.headersSent) return;

  // Body JSON yang rusak adalah kesalahan klien, bukan kesalahan server.
  if (isJsonParseError(error)) {
    res.status(400).json({ message: "Format JSON tidak valid" });
    return;
  }

  res.status(500).json({ message: "Terjadi kesalahan pada server" });
});

export default app;
