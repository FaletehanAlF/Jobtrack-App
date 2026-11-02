import fs from "node:fs/promises";
import { randomUUID } from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import type { ZodError } from "zod";
import { db } from "../config/database.js";
import {
  CLOUDINARY_CV_DELIVERY_TYPE,
  CLOUDINARY_CV_FOLDER,
  CLOUDINARY_CV_RESOURCE_TYPE,
  cloudinaryClient,
  ensureCloudinaryConfigured,
} from "../config/cloudinary.js";
import {
  buildJobseekerApplicationsReport,
  buildRecruiterApplicantsReport,
  buildReportFilename,
  EXCEL_MIME_TYPE,
} from "../reports/application-report.js";
import { createApplicationSchema } from "../validations/application.validation.js";
import { notifyApplicationReceived } from "../services/notification.service.js";
import { CV_MAX_SIZE_BYTES } from "../config/middleware/upload.middleware.js";

interface ApplicationRow extends RowDataPacket {
  id: number;
  applicant_id: number;
  job_id: number;
  status: string;
  created_at: Date | string;
  updated_at: Date | string;
}

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

interface RecruiterApplicantRow extends RowDataPacket {
  id: number;
  status: string;
  created_at: Date | string;
  job_id: number;
  job_title: string;
  job_company: string;
  job_location: string;
  applicant_username: string;
  cv_public_id: string | null;
  cv_resource_type: string | null;
  cv_delivery_type: string | null;
}

const JOBSEEKER_APPLICATIONS_SELECT = `SELECT a.id, a.job_id, a.status,
       a.created_at, a.updated_at,
       j.title AS job_title, j.company AS job_company,
       j.location AS job_location
FROM job_applications a
JOIN jobs j ON j.id = a.job_id`;

const RECRUITER_APPLICANTS_SELECT = `SELECT a.id, a.status, a.created_at,
       j.id AS job_id, j.title AS job_title, j.company AS job_company,
       j.location AS job_location, u.username AS applicant_username,
       a.cv_public_id, a.cv_resource_type, a.cv_delivery_type
FROM job_applications a
JOIN jobs j ON j.id = a.job_id
JOIN users u ON u.id = a.applicant_id`;

const APPLICATION_COLUMNS =
  "id, applicant_id, job_id, status, created_at, updated_at";

const CV_UPLOAD_TIMEOUT_MS = 30_000;

function getFieldErrors(error: ZodError): Record<string, string> {
  const messages: Record<string, string> = {};

  for (const issue of error.issues) {
    const field = issue.path[0];

    if (typeof field !== "string" || field in messages) continue;

    messages[field] = issue.message;
  }

  return messages;
}

async function fetchJobseekerApplicationRows(
  applicantId: number,
): Promise<ApplicationWithJobRow[]> {
  const [rows] = await db.query<ApplicationWithJobRow[]>(
    `${JOBSEEKER_APPLICATIONS_SELECT}
     WHERE a.applicant_id = ?
     ORDER BY a.created_at DESC, a.id DESC`,
    [applicantId],
  );
  return rows;
}

async function fetchRecruiterApplicantRows(
  recruiterId: number,
): Promise<RecruiterApplicantRow[]> {
  const [rows] = await db.query<RecruiterApplicantRow[]>(
    `${RECRUITER_APPLICANTS_SELECT}
     WHERE j.recruiter_id = ?
     ORDER BY a.created_at DESC, a.id DESC`,
    [recruiterId],
  );
  return rows;
}

function sendExcelFile(
  res: Response,
  fileName: string,
  buffer: Buffer,
): void {
  res.setHeader("Content-Type", EXCEL_MIME_TYPE);
  res.setHeader("Content-Disposition", `attachment; filename="${fileName}"`);
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.status(200).send(buffer);
}

const PDF_MAGIC = Buffer.from([0x25, 0x50, 0x44, 0x46]); // %PDF

type CvResourceType = typeof CLOUDINARY_CV_RESOURCE_TYPE;
type CvDeliveryType = typeof CLOUDINARY_CV_DELIVERY_TYPE;

function isPdfFile(filePath: string): Promise<boolean> {
  return (async () => {
    try {
      const handle = await fs.open(filePath, "r");
      try {
        const buffer = Buffer.alloc(4);
        await handle.read(buffer, 0, 4, 0);
        return buffer.equals(PDF_MAGIC);
      } finally {
        await handle.close();
      }
    } catch {
      return false;
    }
  })();
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("CV_UPLOAD_TIMEOUT")),
      timeoutMs,
    );

    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error) => {
        clearTimeout(timer);
        reject(error);
      },
    );
  });
}

/** Log hanya nama error, tanpa detail request/URL/kredensial. */
function logSafeError(context: string, error: unknown): void {
  const name = error instanceof Error ? error.name : "UnknownError";
  console.error(`${context} ${name}`);
}

async function destroyCloudinaryCv(
  publicId: string,
  resourceType: CvResourceType,
  deliveryType: CvDeliveryType,
): Promise<void> {
  try {
    await cloudinaryClient.uploader.destroy(publicId, {
      resource_type: resourceType,
      type: deliveryType,
      invalidate: true,
    });
  } catch (error) {
    logSafeError("[cloudinary-cleanup]", error);
  }
}

export async function createApplication(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const uploadedFile = req.file;

  try {
    if (!req.user) {
      res.status(401).json({ message: "Tidak terautentikasi" });
      return;
    }

    // Validasi body berada di dalam try/finally supaya file sementara tetap
    // dibersihkan ketika job_id tidak ada/tidak valid.
    const result = createApplicationSchema.safeParse(req.body);

    if (!result.success) {
      res.status(400).json({
        message: "Data lamaran tidak valid",
        errors: getFieldErrors(result.error),
      });
      return;
    }

    const jobId = result.data.job_id;
    const applicantId = req.user.id;

    const [existingJobs] = await db.query<RowDataPacket[]>(
      "SELECT id FROM jobs WHERE id = ? LIMIT 1",
      [jobId],
    );

    if (existingJobs.length === 0) {
      res.status(404).json({ message: "Lowongan tidak ditemukan" });
      return;
    }

    let cvPublicId: string | null = null;
    let cvResourceType: CvResourceType | null = null;
    let cvDeliveryType: CvDeliveryType | null = null;

    if (uploadedFile) {
      if (uploadedFile.size === 0) {
        res
          .status(400)
          .json({ message: "File CV kosong. Unggah PDF yang tidak kosong." });
        return;
      }

      if (uploadedFile.size > CV_MAX_SIZE_BYTES) {
        res.status(400).json({ message: "Ukuran CV maksimal 5 MB" });
        return;
      }

      const isPdf = await isPdfFile(uploadedFile.path);
      if (!isPdf) {
        res.status(400).json({ message: "CV harus berupa file PDF yang valid" });
        return;
      }

      if (!ensureCloudinaryConfigured()) {
        res.status(503).json({
          message:
            "Layanan CV belum dikonfigurasi. Hubungi administrator JobTrack.",
        });
        return;
      }

      const expectedPublicId = `${CLOUDINARY_CV_FOLDER}/${randomUUID()}.pdf`;

      let uploadResult: {
        public_id?: string;
        resource_type?: string;
        type?: string;
      };

      try {
        uploadResult = await withTimeout(
          cloudinaryClient.uploader.upload(uploadedFile.path, {
            public_id: expectedPublicId,
            resource_type: CLOUDINARY_CV_RESOURCE_TYPE,
            type: CLOUDINARY_CV_DELIVERY_TYPE,
            use_filename: false,
            unique_filename: false,
            overwrite: false,
          }),
          CV_UPLOAD_TIMEOUT_MS,
        );
      } catch (uploadError) {
        logSafeError("[cloudinary-upload]", uploadError);
        res.status(502).json({ message: "Gagal mengunggah CV. Coba lagi." });
        return;
      }

      const uploadedPublicId =
        typeof uploadResult.public_id === "string"
          ? uploadResult.public_id.trim()
          : "";

      if (
        !uploadedPublicId.startsWith(`${CLOUDINARY_CV_FOLDER}/`) ||
        uploadResult.resource_type !== CLOUDINARY_CV_RESOURCE_TYPE ||
        uploadResult.type !== CLOUDINARY_CV_DELIVERY_TYPE
      ) {
        logSafeError(
          "[cloudinary-upload] respons tidak sesuai",
          new Error("INVALID_UPLOAD_RESULT"),
        );

        if (uploadedPublicId) {
          await destroyCloudinaryCv(
            uploadedPublicId,
            CLOUDINARY_CV_RESOURCE_TYPE,
            CLOUDINARY_CV_DELIVERY_TYPE,
          );
        }

        res.status(502).json({ message: "Gagal mengunggah CV. Coba lagi." });
        return;
      }

      cvPublicId = uploadedPublicId;
      cvResourceType = CLOUDINARY_CV_RESOURCE_TYPE;
      cvDeliveryType = CLOUDINARY_CV_DELIVERY_TYPE;
    }

    let insertId: number;
    try {
      const [insertResult] = await db.query<ResultSetHeader>(
        "INSERT INTO job_applications (applicant_id, job_id, status, cv_public_id, cv_resource_type, cv_delivery_type) VALUES (?, ?, 'submitted', ?, ?, ?)",
        [applicantId, jobId, cvPublicId, cvResourceType, cvDeliveryType],
      );
      insertId = insertResult.insertId;
    } catch (dbError) {
      if (cvPublicId && cvResourceType && cvDeliveryType) {
        await destroyCloudinaryCv(
          cvPublicId,
          cvResourceType,
          cvDeliveryType,
        );
      }

      const databaseError = dbError as { code?: string };

      if (databaseError.code === "ER_DUP_ENTRY") {
        res.status(409).json({
          message: "Lamaran untuk lowongan ini sudah ada",
          errors: { job_id: "Lamaran untuk lowongan ini sudah ada" },
        });
        return;
      }

      if (databaseError.code === "ER_NO_REFERENCED_ROW_2") {
        res.status(404).json({ message: "Lowongan tidak ditemukan" });
        return;
      }

      next(dbError);
      return;
    }

    const [rows] = await db.query<ApplicationRow[]>(
      `SELECT ${APPLICATION_COLUMNS} FROM job_applications WHERE id = ? LIMIT 1`,
      [insertId],
    );

    const application = rows[0];

    if (!application) {
      res.status(500).json({ message: "Gagal mengambil data lamaran" });
      return;
    }

    try {
      const [applicantRows] = await db.query<RowDataPacket[]>(
        "SELECT username FROM users WHERE id = ? LIMIT 1",
        [applicantId],
      );
      const applicant = applicantRows[0] as
        | { username?: string }
        | undefined;

      await notifyApplicationReceived(db, {
        jobId,
        applicationId: application.id,
        applicantUsername: applicant?.username ?? "Pelamar",
      });
    } catch (notificationError) {
      logSafeError("[notification]", notificationError);
    }

    // Referensi Cloudinary tetap internal; jobseeker hanya menerima data
    // lamaran yang memang dibutuhkan UI.
    res.status(201).json({
      application: {
        id: application.id,
        applicant_id: application.applicant_id,
        job_id: application.job_id,
        status: application.status,
        created_at: application.created_at,
        updated_at: application.updated_at,
      },
    });
  } catch (error) {
    next(error);
  } finally {
    if (uploadedFile?.path) {
      try {
        await fs.unlink(uploadedFile.path);
      } catch (unlinkError) {
        const code = (unlinkError as { code?: string }).code;
        if (code !== "ENOENT") {
          logSafeError("[temp-file-cleanup]", unlinkError);
        }
      }
    }
  }
}

export async function listApplications(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const applicantId = req.user.id;

  try {
    const rows = await fetchJobseekerApplicationRows(applicantId);

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

export async function exportJobseekerApplications(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  try {
    const rows = await fetchJobseekerApplicationRows(req.user.id);

    if (rows.length === 0) {
      res.status(404).json({
        message: "Belum ada lamaran untuk diekspor.",
      });
      return;
    }

    const buffer = await buildJobseekerApplicationsReport(
      rows.map((row) => ({
        jobTitle: row.job_title,
        company: row.job_company,
        location: row.job_location,
        status: row.status,
        createdAt: row.created_at,
      })),
    );

    sendExcelFile(res, buildReportFilename("lamaran"), buffer);
  } catch (error) {
    next(error);
  }
}

export async function listRecruiterApplicants(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  try {
    const rows = await fetchRecruiterApplicantRows(req.user.id);

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

    res.status(200).json({ applicants });
  } catch (error) {
    next(error);
  }
}

export async function exportRecruiterApplicants(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  try {
    const rows = await fetchRecruiterApplicantRows(req.user.id);

    if (rows.length === 0) {
      res.status(404).json({
        message: "Belum ada pelamar untuk diekspor.",
      });
      return;
    }

    const buffer = await buildRecruiterApplicantsReport(
      rows.map((row) => ({
        jobTitle: row.job_title,
        company: row.job_company,
        applicantUsername: row.applicant_username,
        status: row.status,
        createdAt: row.created_at,
      })),
    );

    sendExcelFile(res, buildReportFilename("pelamar"), buffer);
  } catch (error) {
    next(error);
  }
}
