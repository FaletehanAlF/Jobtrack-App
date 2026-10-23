import type { NextFunction, Request, Response } from "express";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import type { ZodError } from "zod";
import { db } from "../config/database.js";
import {
  createJobSchema,
  updateJobSchema,
  jobIdSchema,
} from "../validations/job.validation.js";

// Bentuk baris tabel jobs. Hanya kolom ini yang pernah diambil dari database.
interface JobRow extends RowDataPacket {
  id: number;
  recruiter_id: number;
  title: string;
  description: string;
  company: string;
  location: string;
  created_at: Date | string;
  updated_at: Date | string;
}

// Kolom yang dipakai di semua SELECT, supaya tidak perlu menulis berulang.
const JOB_COLUMNS =
  "id, recruiter_id, title, description, company, location, created_at, updated_at";

// Mengubah error Zod menjadi { namaField: pesan } agar frontend bisa
// menampilkan pesan di bawah field yang salah.
function getFieldErrors(error: ZodError): Record<string, string> {
  const messages: Record<string, string> = {};

  for (const issue of error.issues) {
    const field = issue.path[0];

    if (typeof field !== "string" || field in messages) continue;

    messages[field] = issue.message;
  }

  return messages;
}

// GET /api/jobs
export async function listJobs(
  _req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    // Lowongan terbaru tampil lebih dulu. id dipakai sebagai penentu urutan
    // kalau created_at sama, supaya hasilnya selalu konsisten.
    const [jobs] = await db.query<JobRow[]>(
      `SELECT ${JOB_COLUMNS} FROM jobs ORDER BY created_at DESC, id DESC`,
    );

    res.status(200).json({ jobs });
  } catch (error) {
    next(error);
  }
}

// GET /api/jobs/:id
export async function getJob(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const idResult = jobIdSchema.safeParse(req.params.id);

  if (!idResult.success) {
    res.status(400).json({ message: "ID lowongan tidak valid" });
    return;
  }

  const jobId = idResult.data;

  try {
    const [rows] = await db.query<JobRow[]>(
      `SELECT ${JOB_COLUMNS} FROM jobs WHERE id = ? LIMIT 1`,
      [jobId],
    );

    const job = rows[0];

    if (!job) {
      res.status(404).json({ message: "Lowongan tidak ditemukan" });
      return;
    }

    res.status(200).json({ job });
  } catch (error) {
    next(error);
  }
}

// POST /api/jobs
export async function createJob(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  // Middleware authenticate sudah mengisi req.user, tapi TypeScript tetap
  // menganggapnya mungkin kosong.
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const result = createJobSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      message: "Data lowongan tidak valid",
      errors: getFieldErrors(result.error),
    });
    return;
  }

  const title = result.data.title;
  const description = result.data.description;
  const company = result.data.company;
  const location = result.data.location;

  // Pemilik diambil dari token, bukan dari body request. Kalau recruiter_id
  // diterima dari body, recruiter bisa mengaku sebagai orang lain.
  const recruiterId = req.user.id;

  try {
    const [insertResult] = await db.query<ResultSetHeader>(
      "INSERT INTO jobs (recruiter_id, title, description, company, location) VALUES (?, ?, ?, ?, ?)",
      [recruiterId, title, description, company, location],
    );

    const [rows] = await db.query<JobRow[]>(
      `SELECT ${JOB_COLUMNS} FROM jobs WHERE id = ? LIMIT 1`,
      [insertResult.insertId],
    );

    const job = rows[0];

    if (!job) {
      res.status(500).json({ message: "Gagal mengambil data lowongan" });
      return;
    }

    res.status(201).json({ job });
  } catch (error) {
    next(error);
  }
}

// PUT /api/jobs/:id
export async function updateJob(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const idResult = jobIdSchema.safeParse(req.params.id);

  if (!idResult.success) {
    res.status(400).json({ message: "ID lowongan tidak valid" });
    return;
  }

  const result = updateJobSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      message: "Data lowongan tidak valid",
      errors: getFieldErrors(result.error),
    });
    return;
  }

  const jobId = idResult.data;
  const title = result.data.title;
  const description = result.data.description;
  const company = result.data.company;
  const location = result.data.location;
  const recruiterId = req.user.id;

  try {
    // Syarat "id = ? AND recruiter_id = ?" memastikan recruiter hanya bisa
    // mengubah lowongannya sendiri, tanpa perlu mengambil data lebih dulu.
    await db.query<ResultSetHeader>(
      "UPDATE jobs SET title = ?, description = ?, company = ?, location = ? WHERE id = ? AND recruiter_id = ?",
      [title, description, company, location, jobId, recruiterId],
    );

    // Ambil ulang barisnya. Cara ini dipakai karena affectedRows bernilai 0
    // juga ketika data yang dikirim sama persis dengan yang sudah tersimpan,
    // sehingga tidak bisa dipakai untuk membedakan "tidak ada" dan "tidak berubah".
    const [rows] = await db.query<JobRow[]>(
      `SELECT ${JOB_COLUMNS} FROM jobs WHERE id = ? AND recruiter_id = ? LIMIT 1`,
      [jobId, recruiterId],
    );

    const job = rows[0];

    if (!job) {
      res.status(404).json({ message: "Lowongan tidak ditemukan" });
      return;
    }

    res.status(200).json({ job });
  } catch (error) {
    next(error);
  }
}

// DELETE /api/jobs/:id
export async function deleteJob(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const idResult = jobIdSchema.safeParse(req.params.id);

  if (!idResult.success) {
    res.status(400).json({ message: "ID lowongan tidak valid" });
    return;
  }

  const jobId = idResult.data;
  const recruiterId = req.user.id;

  try {
    const [deleteResult] = await db.query<ResultSetHeader>(
      "DELETE FROM jobs WHERE id = ? AND recruiter_id = ?",
      [jobId, recruiterId],
    );

    // 0 baris terhapus berarti lowongan tidak ada atau bukan milik recruiter
    // ini. Keduanya dijawab 404 agar tidak membocorkan lowongan milik orang lain.
    if (deleteResult.affectedRows === 0) {
      res.status(404).json({ message: "Lowongan tidak ditemukan" });
      return;
    }

    res.status(200).json({ message: "Lowongan berhasil dihapus" });
  } catch (error) {
    next(error);
  }
}
