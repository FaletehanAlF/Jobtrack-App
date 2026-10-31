import type { NextFunction, Request, Response } from "express";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import type { ZodError } from "zod";
import { db } from "../config/database.js";
import {
  applicationIdSchema,
  recruiterApplicantsQuerySchema,
  updateApplicationStatusSchema,
} from "../validations/recruiter.validation.js";
import { notifyStatusChanged } from "../services/notification.service.js";

// Bentuk baris hasil agregasi dashboard. Hitungan dikembalikan database,
// bukan dihitung dari daftar panjang di aplikasi.
interface RecruiterJobStatsRow extends RowDataPacket {
  id: number;
  title: string;
  company: string;
  location: string;
  created_at: Date | string;
  applicant_count: number | string;
  submitted_count: number | string;
  rejected_count: number | string;
}

// Satu baris pelamar pada daftar recruiter (versi berfilter).
interface RecruiterApplicantFilteredRow extends RowDataPacket {
  id: number;
  status: string;
  created_at: Date | string;
  job_id: number;
  job_title: string;
  job_company: string;
  job_location: string;
  applicant_username: string;
}

interface TotalRow extends RowDataPacket {
  total: number | string;
}

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

// COUNT dikembalikan mysql2 sebagai angka, tetapi tipe BIGINT bisa menjadi
// string pada beberapa konfigurasi driver. Number() membuat keduanya aman.
function toCount(value: number | string): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

// GET /api/recruiter/dashboard
//
// Satu query agregasi untuk seluruh lowongan milik recruiter login. JOIN
// memakai LEFT agar lowongan tanpa pelamar tetap muncul dengan hitungan 0.
// Filter kepemilikan memakai j.recruiter_id dari token, bukan dari query.
export async function getRecruiterDashboard(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  try {
    const [rows] = await db.query<RecruiterJobStatsRow[]>(
      `SELECT j.id, j.title, j.company, j.location, j.created_at,
              COUNT(a.id) AS applicant_count,
              COUNT(CASE WHEN a.status = 'submitted' THEN 1 END) AS submitted_count,
              COUNT(CASE WHEN a.status = 'rejected' THEN 1 END) AS rejected_count
       FROM jobs j
       LEFT JOIN job_applications a ON a.job_id = j.id
       WHERE j.recruiter_id = ?
       GROUP BY j.id, j.title, j.company, j.location, j.created_at
       ORDER BY j.created_at DESC, j.id DESC`,
      [req.user.id],
    );

    let applicants = 0;
    let submitted = 0;
    let rejected = 0;

    const jobs = rows.map((row) => {
      const applicantCount = toCount(row.applicant_count);
      const submittedCount = toCount(row.submitted_count);
      const rejectedCount = toCount(row.rejected_count);

      applicants += applicantCount;
      submitted += submittedCount;
      rejected += rejectedCount;

      return {
        id: row.id,
        title: row.title,
        company: row.company,
        location: row.location,
        created_at: row.created_at,
        applicant_count: applicantCount,
        submitted_count: submittedCount,
        rejected_count: rejectedCount,
      };
    });

    res.status(200).json({
      stats: {
        jobs: jobs.length,
        applicants,
        submitted,
        rejected,
      },
      jobs,
    });
  } catch (error) {
    next(error);
  }
}

// GET /api/recruiter/applicants
//
// Daftar pelamar untuk lowongan milik recruiter login, dengan filter
// lowongan/status dan pagination. Filter hanya mempersempit hasil yang
// sudah dibatasi kepemilikan; frontend tidak dipakai sebagai pengaman.
export async function listRecruiterApplicantsFiltered(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const queryResult = recruiterApplicantsQuerySchema.safeParse(req.query);

  if (!queryResult.success) {
    res.status(400).json({
      message: "Parameter daftar pelamar tidak valid",
      errors: getFieldErrors(queryResult.error),
    });
    return;
  }

  const { job_id: jobId, status, limit, offset } = queryResult.data;

  // Kondisi kepemilikan selalu ada, apa pun filter yang dikirim pengguna.
  const conditions = ["j.recruiter_id = ?"];
  const params: unknown[] = [req.user.id];

  if (jobId !== undefined) {
    conditions.push("a.job_id = ?");
    params.push(jobId);
  }

  if (status !== undefined) {
    conditions.push("a.status = ?");
    params.push(status);
  }

  const whereClause = conditions.join(" AND ");

  try {
    const [countRows] = await db.query<TotalRow[]>(
      `SELECT COUNT(*) AS total
       FROM job_applications a
       JOIN jobs j ON j.id = a.job_id
       WHERE ${whereClause}`,
      params,
    );

    const [rows] = await db.query<RecruiterApplicantFilteredRow[]>(
      `SELECT a.id, a.status, a.created_at,
              j.id AS job_id, j.title AS job_title, j.company AS job_company,
              j.location AS job_location, u.username AS applicant_username
       FROM job_applications a
       JOIN jobs j ON j.id = a.job_id
       JOIN users u ON u.id = a.applicant_id
       WHERE ${whereClause}
       ORDER BY a.created_at DESC, a.id DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    const applicants = rows.map((row) => ({
      id: row.id,
      status: row.status,
      created_at: row.created_at,
      applicant: {
        username: row.applicant_username,
      },
      job: {
        id: row.job_id,
        title: row.job_title,
        company: row.job_company,
        location: row.job_location,
      },
    }));

    res.status(200).json({
      applicants,
      total: toCount(countRows[0]?.total ?? 0),
      limit,
      offset,
    });
  } catch (error) {
    next(error);
  }
}

// PATCH /api/applications/:id/status (khusus recruiter)
//
// Kepemilikan diverifikasi di dalam UPDATE itu sendiri lewat JOIN ke jobs,
// sehingga lamaran milik lowongan recruiter lain tidak bisa diubah meskipun
// ID-nya ditebak. affectedRows 0 berarti "tidak ada" atau "bukan milikmu" —
// keduanya dijawab 404 agar tidak membocorkan keberadaan lamaran orang lain.
export async function updateApplicationStatus(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const idResult = applicationIdSchema.safeParse(req.params.id);

  if (!idResult.success) {
    res.status(400).json({ message: "ID lamaran tidak valid" });
    return;
  }

  const bodyResult = updateApplicationStatusSchema.safeParse(req.body);

  if (!bodyResult.success) {
    res.status(400).json({
      message: "Status lamaran tidak valid",
      errors: getFieldErrors(bodyResult.error),
    });
    return;
  }

  const applicationId = idResult.data;
  const status = bodyResult.data.status;

  const connection = await db.getConnection();

  try {
    // Transaksi: UPDATE status dan INSERT notifikasi harus berhasil bersama.
    // Kalau notifikasi gagal, status ikut dibatalkan sehingga tidak ada
    // notifikasi untuk perubahan yang tidak tersimpan — dan sebaliknya tidak
    // ada perubahan status yang diam-diam tanpa notifikasi.
    await connection.beginTransaction();

    // Status sebelum perubahan dibaca di dalam transaksi agar perubahan
    // dapat dibedakan dari "tidak ada perubahan" (affectedRows 0 pada
    // UPDATE juga terjadi saat nilai baru sama dengan nilai lama).
    const [beforeRows] = await connection.query<
      Array<RowDataPacket & { status: string; job_id: number }>
    >(
      `SELECT a.status, a.job_id, j.title AS job_title, a.applicant_id
       FROM job_applications a
       JOIN jobs j ON j.id = a.job_id
       WHERE a.id = ? AND j.recruiter_id = ?
       LIMIT 1`,
      [applicationId, req.user.id],
    );

    const before = beforeRows[0];

    if (!before) {
      await connection.rollback();
      res.status(404).json({ message: "Lamaran tidak ditemukan" });
      return;
    }

    await connection.query<ResultSetHeader>(
      `UPDATE job_applications a
       JOIN jobs j ON j.id = a.job_id
       SET a.status = ?
       WHERE a.id = ? AND j.recruiter_id = ?`,
      [status, applicationId, req.user.id],
    );

    const statusChanged = before.status !== status;

    // Notifikasi hanya dibuat bila status BENAR-BENAR berubah. Menekan
    // "Tolak" dua kali pada lamaran yang sudah rejected tidak menghasilkan
    // notifikasi baru.
    if (statusChanged) {
      const [titleRows] = await connection.query<
        Array<RowDataPacket & { title: string }>
      >("SELECT title FROM jobs WHERE id = ? LIMIT 1", [before.job_id]);

      await notifyStatusChanged(connection, {
        applicantId: before.applicant_id,
        applicationId,
        jobId: before.job_id,
        jobTitle: titleRows[0]?.title ?? "",
        status,
      });
    }

    await connection.commit();

    // Data untuk respons dibaca setelah commit supaya yang dikirim adalah
    // keadaan yang benar-benar tersimpan.
    const [rows] = await db.query<RecruiterApplicantFilteredRow[]>(
      `SELECT a.id, a.status, a.created_at,
              j.id AS job_id, j.title AS job_title, j.company AS job_company,
              j.location AS job_location, u.username AS applicant_username
       FROM job_applications a
       JOIN jobs j ON j.id = a.job_id
       JOIN users u ON u.id = a.applicant_id
       WHERE a.id = ? AND j.recruiter_id = ?
       LIMIT 1`,
      [applicationId, req.user.id],
    );

    const row = rows[0];

    if (!row) {
      res.status(404).json({ message: "Lamaran tidak ditemukan" });
      return;
    }

    res.status(200).json({
      application: {
        id: row.id,
        status: row.status,
        created_at: row.created_at,
        applicant: {
          username: row.applicant_username,
        },
        job: {
          id: row.job_id,
          title: row.job_title,
          company: row.job_company,
          location: row.job_location,
        },
      },
    });
  } catch (error) {
    // Rollback aman dipanggil walau transaksi sudah commit/gagal.
    await connection.rollback().catch(() => undefined);

    // Mengembalikan lamaran lama ke 'submitted' saat pelamar sudah punya
    // lamaran aktif lain untuk lowongan yang sama melanggar
    // UNIQUE(applicant_id, job_id, active_slot). Dijawab 409 agar recruiter
    // tahu sebabnya, bukan 500.
    const databaseError = error as { code?: string };

    if (databaseError.code === "ER_DUP_ENTRY") {
      res.status(409).json({
        message:
          "Pelamar ini sudah memiliki lamaran aktif untuk lowongan yang sama.",
      });
      return;
    }

    next(error);
  } finally {
    connection.release();
  }
}
