import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";
import fs from "node:fs/promises";
import type { NextFunction, Request, Response } from "express";
import multer from "multer";

export const CV_MAX_SIZE_BYTES = 5 * 1024 * 1024;

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, os.tmpdir());
  },
  filename: (req, file, cb) => {
    const fileName = `jobtrack-cv-${randomUUID()}.pdf`;
    const fullPath = path.join(os.tmpdir(), fileName);
    (req as Request & { cvTempPath?: string }).cvTempPath = fullPath;

    cb(null, fileName);
  },
});

export const uploadCv = multer({
  storage,
  limits: {
    fileSize: CV_MAX_SIZE_BYTES,
    files: 1,
    fields: 5,
    parts: 10,
    fieldSize: 16 * 1024,
  },
});

export class CvUploadError extends Error {
  status: number;
  code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function mapMulterErrorToCvUploadError(error: multer.MulterError): CvUploadError {
  switch (error.code) {
    case "LIMIT_FILE_SIZE":
      return new CvUploadError(
        400,
        "CV_TOO_LARGE",
        "Ukuran CV maksimal 5 MB",
      );
    case "LIMIT_UNEXPECTED_FILE":
    case "LIMIT_FILE_COUNT":
      return new CvUploadError(
        400,
        "CV_FIELD_INVALID",
        "Kirim CV melalui field 'cv' dengan satu file PDF",
      );
    default:
      return new CvUploadError(
        400,
        "CV_UPLOAD_REJECTED",
        "File CV tidak dapat diproses",
      );
  }
}

export function handleCvUpload(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  uploadCv.single("cv")(req, res, (error: unknown) => {
    if (!error) {
      next();
      return;
    }

    void (async () => {
      const request = req as Request & { cvTempPath?: string };
      const uploadedPath = req.file?.path ?? request.cvTempPath;

      if (uploadedPath) {
        try {
          await fs.unlink(uploadedPath);
        } catch (cleanupError) {
          const code = (cleanupError as { code?: string }).code;
          if (code !== "ENOENT") {
            console.error(
              "[cv-upload-cleanup] gagal menghapus file sementara:",
              cleanupError instanceof Error ? cleanupError.name : "UnknownError",
            );
          }
        }
      }

      if (error instanceof multer.MulterError) {
        const mapped = mapMulterErrorToCvUploadError(error);
        res.status(mapped.status).json({ message: mapped.message });
        return;
      }

      next(error);
    })();
  });
}
