import type { NextFunction, Request, Response } from "express";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import type { ZodError } from "zod";
import { db } from "../config/database.js";
import { createApplicationSchema } from "../validations/application.validation.js";

// Bentuk baris tabel job_applications. Hanya kolom ini yang pernah diambil
// dari database. Kolom active_slot (kolom hasil turunan migration) sengaja
// tidak pernah diambil karena hanya kepentingan database, bukan kepentingan API.
interface ApplicationRow extends RowDataPacket {
  id: number;
  applicant_id: number;
  job_id: number;
  status: string;
  created_at: Date | string;
  updated_at: Date | string;
}

// Bentuk baris lamaran yang sudah digabung dengan lowongannya, untuk daftar
// riwayat lamaran milik jobseeker.
interface ApplicationWithJobRow extends RowDataPacket {
  id: number;
  job_id: number;
  status: string;
  created_at: Date | string;
  updated_at: Date | string;
  job_title: string;
  job_company: string;
  job_location: string;
}

// Kolom hasil SELECT untuk respons POST. Status tidak pernah diambil dari
// body request; nilainya selalu 'submitted' pada saat pengajuan baru.
const APPLICATION_COLUMNS =
  "id, applicant_id, job_id, status, created_at, updated_at";

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

// POST /api/applications
export async function createApplication(
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

  const result = createApplicationSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      message: "Data lamaran tidak valid",
      errors: getFieldErrors(result.error),
    });
    return;
  }

  const jobId = result.data.job_id;

  // Pelamar diambil dari token, bukan dari body request. Kalau applicant_id
  // diterima dari body, jobseeker bisa mengaku sebagai orang lain.
  const applicantId = req.user.id;

  try {
    // Cek lowongan lebih dulu supaya pesan errornya jelas 404. Status lowongan
    // (buka/tutup) belum ada di tabel jobs, jadi satu-satunya cek saat ini
    // adalah keberadaan lowongan.
    const [existingJobs] = await db.query<RowDataPacket[]>(
      "SELECT id FROM jobs WHERE id = ? LIMIT 1",
      [jobId],
    );

    if (existingJobs.length === 0) {
      res.status(404).json({ message: "Lowongan tidak ditemukan" });
      return;
    }

    // Setiap pengajuan membuat baris baru, bukan memperbarui baris lama,
    // sehingga riwayat lamaran tidak pernah hilang. Pembatalan ganda untuk
    // pasangan pelamar-lowongan ditolak oleh UNIQUE(applicant_id, job_id,
    // active_slot) di database, termasuk untuk request bersamaan.
    const [insertResult] = await db.query<ResultSetHeader>(
      "INSERT INTO job_applications (applicant_id, job_id, status) VALUES (?, ?, 'submitted')",
      [applicantId, jobId],
    );

    // Waktu pembuatan aktual ditetapkan oleh database, jadi barisnya
    // ditarik ulang supaya respons memuat created_at persis seperti di DB.
    const [rows] = await db.query<ApplicationRow[]>(
      `SELECT ${APPLICATION_COLUMNS} FROM job_applications WHERE id = ? LIMIT 1`,
      [insertResult.insertId],
    );

    const application = rows[0];

    if (!application) {
      res.status(500).json({ message: "Gagal mengambil data lamaran" });
      return;
    }

    res.status(201).json({ application });
  } catch (error) {
    // Database juga menolak lamaran aktif duplikat lewat
    // UNIQUE(applicant_id, job_id, active_slot). Ini menangani kasus dua
    // request melamar bersamaan, yang lolos dari pengecekan di atas.
    const databaseError = error as { code?: string };

    if (databaseError.code === "ER_DUP_ENTRY") {
      res.status(409).json({
        message: "Lamaran untuk lowongan ini sudah ada",
        errors: { job_id: "Lamaran untuk lowongan ini sudah ada" },
      });
      return;
    }

    if (databaseError.code === "ER_NO_REFERENCED_ROW_2") {
      // Lowongan bisa terhapus oleh request lain di antara SELECT di atas
      // dan INSERT di bawah. FK menolak INSERT dalam kondisi itu, jadi
      // dijawab sama seperti saat lowongan memang tidak ada.
      res.status(404).json({ message: "Lowongan tidak ditemukan" });
      return;
    }

    next(error);
  }
}

// GET /api/applications
export async function listApplications(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  // Pelamar hanya melihat lamarannya sendiri. applicant_id selalu dari token,
  // tidak pernah dari query string, supaya tidak bisa memakai identitas orang lain.
  const applicantId = req.user.id;

  try {
    // Riwayat berisi semua status, termasuk lamaran yang sudah ditolak,
    // supaya alur lamaran ulang bisa dipahami pengguna.
    // JOIN (bukan LEFT JOIN) karena FK dengan ON DELETE CASCADE menjamin
    // setiap lamaran selalu punya lowongannya.
    const [rows] = await db.query<ApplicationWithJobRow[]>(
      `SELECT a.id, a.job_id, a.status, a.created_at, a.updated_at,
              j.title AS job_title, j.company AS job_company,
              j.location AS job_location
       FROM job_applications a
       JOIN jobs j ON j.id = a.job_id
       WHERE a.applicant_id = ?
       ORDER BY a.created_at DESC, a.id DESC`,
      [applicantId],
    );

    const applications = rows.map((row) => ({
      id: row.id,
      job_id: row.job_id,
      status: row.status,
      created_at: row.created_at,
      job: {
        id: row.job_id,
        title: row.job_title,
        company: row.job_company,
        location: row.job_location,
      },
    }));

    res.status(200).json({ applications });
  } catch (error) {
    next(error);
  }
}
