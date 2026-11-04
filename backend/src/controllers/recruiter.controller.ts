import type { NextFunction, Request, Response } from "express";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import jwt from "jsonwebtoken";
import type { ZodError } from "zod";
import { db } from "../config/database.js";
import {
  CLOUDINARY_CV_DELIVERY_TYPE,
  CLOUDINARY_CV_RESOURCE_TYPE,
  cloudinaryClient,
  ensureCloudinaryConfigured,
} from "../config/cloudinary.js";
import { CV_MAX_SIZE_BYTES } from "../config/middleware/upload.middleware.js";

const CV_STREAM_TOKEN_PURPOSE = "cv-stream";
const CV_URL_TTL_SECONDS = 300;
const CV_FETCH_TTL_SECONDS = 120;
const CV_FETCH_TIMEOUT_MS = 15_000;
import {
  applicationIdSchema,
  recruiterApplicantsQuerySchema,
  updateApplicationStatusSchema,
} from "../validations/recruiter.validation.js";
import { notifyStatusChanged } from "../services/notification.service.js";

const PDF_MAGIC = Buffer.from([0x25, 0x50, 0x44, 0x46]); // %PDF

/** Log hanya nama error, tanpa detail request/URL/kredensial. */
function logSafeError(context: string, error: unknown): void {
  const name = error instanceof Error ? error.name : "UnknownError";
  console.error(`${context} ${name}`);
}

function isPdfBuffer(buffer: Buffer): boolean {
  return buffer.length >= PDF_MAGIC.length && buffer.subarray(0, 4).equals(PDF_MAGIC);
}

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

interface RecruiterApplicantFilteredRow extends RowDataPacket {
  id: number;
  status: string;
  created_at: Date | string;
  job_id: number;
  job_title: string;
  job_company: string;
  job_location: string;
  applicant_username: string;
  cv_public_id: string | null;
}

interface TotalRow extends RowDataPacket {
  total: number | string;
}

function getFieldErrors(error: ZodError): Record<string, string> {
  const messages: Record<string, string> = {};

  for (const issue of error.issues) {
    const field = issue.path[0];

    if (typeof field !== "string" || field in messages) continue;

    messages[field] = issue.message;
  }

  return messages;
}

function toCount(value: number | string): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

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
              j.location AS job_location, u.username AS applicant_username,
              a.cv_public_id
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
      has_cv: Boolean(row.cv_public_id),
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
    await connection.beginTransaction();

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
    await connection.rollback().catch(() => undefined);

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

export async function getRecruiterApplicantCv(
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

  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    next(
      new Error(
        "JWT_SECRET belum diatur. Tambahkan JWT_SECRET di backend/.env sebelum memakai akses CV.",
      ),
    );
    return;
  }

  if (!ensureCloudinaryConfigured()) {
    res.status(503).json({
      message:
        "Layanan CV belum dikonfigurasi. Hubungi administrator JobTrack.",
    });
    return;
  }

  const applicationId = idResult.data;

  try {
    const [rows] = await db.query<
      Array<RowDataPacket & { has_cv: number }>
    >(
      `SELECT (a.cv_public_id IS NOT NULL) AS has_cv
       FROM job_applications a
       JOIN jobs j ON j.id = a.job_id
       WHERE a.id = ? AND j.recruiter_id = ?
       LIMIT 1`,
      [applicationId, req.user.id],
    );

    const row = rows[0];

    if (!row) {
      res.status(404).json({ message: "Lamaran tidak ditemukan" });
      return;
    }

    if (!row.has_cv) {
      res.status(404).json({ message: "CV tidak tersedia untuk lamaran ini" });
      return;
    }

    // Token akses berumur pendek milik backend sendiri. URL Cloudinary tidak
    // pernah dikirim ke klien; pengambilan file tetap melewati backend
    // (streamRecruiterApplicantCv) yang memvalidasi token dan kepemilikan
    // job secara ulang.
    const expiresAt = Math.floor(Date.now() / 1000) + CV_URL_TTL_SECONDS;
    const token = jwt.sign(
      {
        purpose: CV_STREAM_TOKEN_PURPOSE,
        applicationId,
        recruiterId: req.user.id,
      },
      jwtSecret,
      { expiresIn: CV_URL_TTL_SECONDS, algorithm: "HS256" },
    );

    const base = `${req.protocol}://${req.get("host") ?? `localhost:${process.env.PORT ?? 3000}`}`;
    const streamPath = `/api/recruiter/applicants/${applicationId}/cv/stream?token=${token}`;
    const url = `${base}${streamPath}`;

    res.status(200).json({
      url,
      download_url: `${url}&download=1`,
      expires_at: expiresAt,
    });
  } catch (error) {
    logSafeError("[cv-access]", error);
    res.status(500).json({ message: "Gagal membuat akses CV" });
  }
}

export async function streamRecruiterApplicantCv(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const tokenParam = req.query?.token;

  if (typeof tokenParam !== "string" || tokenParam.length === 0) {
    res.status(401).json({ message: "Tautan CV tidak valid" });
    return;
  }

  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    next(
      new Error(
        "JWT_SECRET belum diatur. Tambahkan JWT_SECRET di backend/.env sebelum memakai akses CV.",
      ),
    );
    return;
  }

  let recruiterId: number;
  let applicationId: number;

  try {
    const payload = jwt.verify(
      tokenParam,
      jwtSecret,
      { algorithms: ["HS256"] },
    ) as { purpose?: unknown; applicationId?: unknown; recruiterId?: unknown };

    if (
      payload.purpose !== CV_STREAM_TOKEN_PURPOSE ||
      typeof payload.applicationId !== "number" ||
      typeof payload.recruiterId !== "number"
    ) {
      res
        .status(401)
        .json({ message: "Tautan CV tidak valid atau sudah kedaluwarsa" });
      return;
    }

    recruiterId = payload.recruiterId;
    applicationId = payload.applicationId;
  } catch {
    res
      .status(401)
      .json({ message: "Tautan CV tidak valid atau sudah kedaluwarsa" });
    return;
  }

  if (!ensureCloudinaryConfigured()) {
    res.status(503).json({
      message:
        "Layanan CV belum dikonfigurasi. Hubungi administrator JobTrack.",
    });
    return;
  }

  const download = req.query.download === "1" || req.query.download === "true";

  try {
    const [rows] = await db.query<
      Array<RowDataPacket & {
        cv_public_id: string | null;
        cv_resource_type: string | null;
        cv_delivery_type: string | null;
      }>
    >(
      `SELECT a.cv_public_id, a.cv_resource_type, a.cv_delivery_type
       FROM job_applications a
       JOIN jobs j ON j.id = a.job_id
       WHERE a.id = ? AND j.recruiter_id = ?
       LIMIT 1`,
      [applicationId, recruiterId],
    );

    const row = rows[0];

    if (!row) {
      res.status(404).json({ message: "Lamaran tidak ditemukan" });
      return;
    }

    if (!row.cv_public_id) {
      res.status(404).json({ message: "CV tidak tersedia untuk lamaran ini" });
      return;
    }

    const resourceType =
      row.cv_resource_type === "image" ||
      row.cv_resource_type === "video" ||
      row.cv_resource_type === "raw"
        ? row.cv_resource_type
        : CLOUDINARY_CV_RESOURCE_TYPE;

    const deliveryType =
      row.cv_delivery_type === "upload" ||
      row.cv_delivery_type === "private" ||
      row.cv_delivery_type === "authenticated"
        ? row.cv_delivery_type
        : CLOUDINARY_CV_DELIVERY_TYPE;

    const downloadUrl = cloudinaryClient.utils.private_download_url(
      row.cv_public_id,
      "pdf",
      {
        resource_type: resourceType,
        type: deliveryType,
        expires_at: Math.floor(Date.now() / 1000) + CV_FETCH_TTL_SECONDS,
        attachment: false,
      },
    );

    let response: Awaited<ReturnType<typeof fetch>>;

    try {
      response = await fetch(downloadUrl, {
        signal: AbortSignal.timeout(CV_FETCH_TIMEOUT_MS),
        headers: { Accept: "application/pdf" },
      });
    } catch (fetchError) {
      console.error(
        "[cv-stream] gagal mengambil CV dari Cloudinary:",
        fetchError instanceof Error ? fetchError.name : fetchError,
      );
      res
        .status(502)
        .json({ message: "CV tidak dapat diakses saat ini. Coba lagi." });
      return;
    }

    if (!response.ok) {
      console.error("[cv-stream] Cloudinary merespons", response.status);
      res
        .status(502)
        .json({ message: "CV tidak dapat diakses saat ini. Coba lagi." });
      return;
    }

    const buffer = Buffer.from(await response.arrayBuffer());

    if (
      buffer.length === 0 ||
      buffer.length > CV_MAX_SIZE_BYTES ||
      !isPdfBuffer(buffer)
    ) {
      logSafeError(
        "[cv-stream] konten CV tidak valid",
        new Error("INVALID_CV_CONTENT"),
      );
      res
        .status(502)
        .json({ message: "CV tidak dapat diakses saat ini. Coba lagi." });
      return;
    }

    res.status(200);
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      download
        ? 'attachment; filename="cv-lamaran.pdf"'
        : 'inline; filename="cv-lamaran.pdf"',
    );
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("Cache-Control", "no-store");
    res.send(buffer);
  } catch (error) {
    logSafeError("[cv-stream]", error);
    if (!res.headersSent) {
      res
        .status(500)
        .json({ message: "CV tidak dapat diakses saat ini. Coba lagi." });
    }
  }
}
