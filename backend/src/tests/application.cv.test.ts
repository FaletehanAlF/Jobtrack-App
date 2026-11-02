import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { Request } from "express";

// Spell database dulu: modul ini memanggil dotenv.config(), sehingga env
// (CLOUDINARY_*, JWT_SECRET*) sudah terisi sebelum config Cloudinary dievaluasi.
import { db } from "../config/database.js";
import { cloudinaryClient } from "../config/cloudinary.js";
import { createApplication } from "../controllers/application.controller.js";
import { CV_MAX_SIZE_BYTES } from "../config/middleware/upload.middleware.js";
import { callController, makeReq, stubPoolQuery } from "./helpers.js";

type ApplyRequest = Omit<Request, "file"> & { file?: { path: string; size: number } };

/** Baris lamaran yang "tersimpan" untuk kasus sukses. */
const savedApplication = {
  id: 88,
  applicant_id: 5,
  job_id: 7,
  status: "submitted",
  created_at: new Date(2026, 0, 20, 8),
  updated_at: new Date(2026, 0, 20, 8),
};

interface DbScenario {
  jobExists?: boolean;
  insertId?: number;
  /** Error yang dilempar INSERT job_applications, meniru mysql2 reject. */
  insertError?: { code: string };
}

/**
 * Stub pool.query untuk seluruh skema query yang dipakai createApplication.
 * Mengembalikan fungsi restore.
 */
function stubApplicationDb(scenario: DbScenario = {}) {
  let insertedParams: unknown[] | null = null;
  let notificationInserted = false;

  const stub = stubPoolQuery((sql, params) => {
    if (sql.startsWith("SELECT id FROM jobs")) {
      return [[{ id: scenario.jobExists === false ? undefined : 7 }].filter((job) => job.id !== undefined)];
    }

    if (sql.startsWith("INSERT INTO job_applications")) {
      insertedParams = params ?? null;
      if (scenario.insertError) return Promise.reject(scenario.insertError);
      return [[{ insertId: scenario.insertId ?? 88 }], []];
    }

    if (sql.startsWith("SELECT id, applicant_id, job_id, status,")) {
      return [
        [
          {
            ...savedApplication,
            id: scenario.insertId ?? 88,
            applicant_id: insertedParams?.[0] ?? 5,
            job_id: insertedParams?.[1] ?? 7,
          },
        ],
      ];
    }

    if (sql.startsWith("SELECT username FROM users")) {
      return [[{ username: "budi" }]];
    }

    if (sql.startsWith("SELECT recruiter_id, title FROM jobs")) {
      return [[{ recruiter_id: 3, title: "Backend Developer" }]];
    }

    if (sql.startsWith("INSERT IGNORE INTO notifications")) {
      notificationInserted = true;
      return [{ affectedRows: 1 }];
    }

    return [[], []];
  });

  return {
    restore: stub.restore,
    get insertedParams() {
      return insertedParams;
    },
    get notificationInserted() {
      return notificationInserted;
    },
    get insertCalled() {
      return stub.calls.some((c) => c.sql.startsWith("INSERT INTO job_applications"));
    },
  };
}

function applyRequest(file?: { path: string; size: number }): Request {
  const req = makeReq(
    { id: 5, role: "jobseeker" },
    { job_id: 7 },
  ) as unknown as ApplyRequest;

  req.file = file;
  return req as unknown as Request;
}

interface CloudinarySpy {
  restore: () => void;
  uploadCalls: Array<{ path: string; options: Record<string, unknown> }>;
  destroyCalls: Array<{ publicId: string; options: Record<string, unknown> }>;
  setUploadError(error: unknown): void;
  setDestroyError(error: unknown): void;
}

function stubCloudinary(): CloudinarySpy {
  const uploader = cloudinaryClient.uploader as unknown as {
    upload: (filePath: string, options: unknown) => Promise<unknown>;
    destroy: (publicId: string, options: unknown) => Promise<unknown>;
  };
  const originalUpload = uploader.upload;
  const originalDestroy = uploader.destroy;

  const uploadCalls: Array<{ path: string; options: Record<string, unknown> }> = [];
  const destroyCalls: Array<{ publicId: string; options: Record<string, unknown> }> = [];
  let uploadError: unknown = null;
  let destroyError: unknown = null;

  uploader.upload = (filePath, options) => {
    uploadCalls.push({ path: filePath, options: options as Record<string, unknown> });
    if (uploadError) return Promise.reject(uploadError);
    return Promise.resolve({
      public_id: "jobtrack/cvs/stub-1",
      resource_type: "raw",
      type: "authenticated",
    });
  };

  uploader.destroy = (publicId, options) => {
    destroyCalls.push({ publicId, options: options as Record<string, unknown> });
    if (destroyError) return Promise.reject(destroyError);
    return Promise.resolve({ result: "ok" });
  };

  return {
    uploadCalls,
    destroyCalls,
    setUploadError(error) {
      uploadError = error;
    },
    setDestroyError(error) {
      destroyError = error;
    },
    restore() {
      uploader.upload = originalUpload;
      uploader.destroy = originalDestroy;
    },
  };
}

async function writeTempFile(content: Buffer): Promise<string> {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "jt-cv-"));
  const filePath = path.join(dir, "upload-target.pdf");
  await fsp.writeFile(filePath, content);
  return filePath;
}

async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fsp.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function assertFileGone(filePath: string): Promise<void> {
  assert.equal(
    await fileExists(filePath),
    false,
    `file sementara masih ada: ${filePath}`,
  );
}

describe("POST /api/applications dengan CV", () => {
  let tempDir: string;

  before(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "jt-cv-suite-"));
  });

  after(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  it("mengunggah PDF valid ke Cloudinary lalu menyimpan referensinya", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb();
    const filePath = path.join(tempDir, "valid.pdf");
    await fsp.writeFile(filePath, Buffer.from("%PDF-1.4\n%%EOF\n"));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 15 }),
      );

      assert.equal(capture.status, 201);
      assert.deepEqual(capture.body, {
        application: {
          ...savedApplication,
        },
      });

      assert.equal(cloudSpy.uploadCalls.length, 1);
      assert.equal(
        cloudSpy.uploadCalls[0].options.resource_type,
        "raw",
      );
      assert.equal(
        cloudSpy.uploadCalls[0].options.type,
        "authenticated",
      );
      assert.equal(
        cloudSpy.uploadCalls[0].options.use_filename,
        false,
      );
      assert.equal(
        cloudSpy.uploadCalls[0].options.unique_filename,
        false,
      );
      assert.equal(
        cloudSpy.uploadCalls[0].options.overwrite,
        false,
      );
      assert.equal(stubDb.insertCalled, true);
      assert.deepEqual(stubDb.insertedParams, [
        5,
        7,
        "jobtrack/cvs/stub-1",
        "raw",
        "authenticated",
      ]);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("membuat lamaran tanpa CV tetap berjalan seperti perilaku lama", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb();

    try {
      const capture = await callController(
        createApplication,
        applyRequest(undefined),
      );

      assert.equal(capture.status, 201);
      assert.equal(cloudSpy.uploadCalls.length, 0);
      assert.equal(stubDb.insertCalled, true);
      assert.deepEqual(stubDb.insertedParams, [5, 7, null, null, null]);
      assert.equal(stubDb.notificationInserted, true);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
    }
  });

  it("menolak file dengan signature bukan PDF", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb();
    const filePath = path.join(tempDir, "fake-pdf.pdf");
    await fsp.writeFile(filePath, Buffer.from("GIF89a-not-a-pdf"));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 14 }),
      );

      assert.equal(capture.status, 400);
      assert.match(
        (capture.body as { message?: string }).message ?? "",
        /PDF yang valid/,
      );
      assert.equal(cloudSpy.uploadCalls.length, 0);
      assert.equal(stubDb.insertCalled, false);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("menolak file kosong", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb();
    const filePath = path.join(tempDir, "empty.pdf");
    await fsp.writeFile(filePath, Buffer.alloc(0));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 0 }),
      );

      assert.equal(capture.status, 400);
      assert.match((capture.body as { message?: string }).message ?? "", /kosong/);
      assert.equal(cloudSpy.uploadCalls.length, 0);
      assert.equal(stubDb.insertCalled, false);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("menolak file lebih dari 5 MB", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb();
    const bigBuffer = Buffer.concat([
      Buffer.from("%PDF-1.4\n"),
      Buffer.alloc(CV_MAX_SIZE_BYTES + 1, 0x41),
    ]);
    const filePath = path.join(tempDir, "too-big.pdf");
    await fsp.writeFile(filePath, bigBuffer);

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: bigBuffer.length }),
      );

      assert.equal(capture.status, 400);
      assert.match((capture.body as { message?: string }).message ?? "", /5 MB/);
      assert.equal(cloudSpy.uploadCalls.length, 0);
      assert.equal(stubDb.insertCalled, false);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("mengembalikan 502 tanpa menyimpan data saat upload Cloudinary gagal", async () => {
    const cloudSpy = stubCloudinary();
    cloudSpy.setUploadError(new Error("cloudinary down"));
    const stubDb = stubApplicationDb();
    const filePath = path.join(tempDir, "cloud-fail.pdf");
    await fsp.writeFile(filePath, Buffer.from("%PDF-1.4 x"));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 11 }),
      );

      assert.equal(capture.status, 502);
      assert.match((capture.body as { message?: string }).message ?? "", /Coba lagi/);
      assert.equal(cloudSpy.uploadCalls.length, 1);
      assert.equal(cloudSpy.destroyCalls.length, 0);
      assert.equal(stubDb.insertCalled, false);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("membersihkan aset Cloudinary saat penyimpanan database gagal (duplikat)", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb({
      insertError: { code: "ER_DUP_ENTRY" },
    });
    const filePath = path.join(tempDir, "dup.pdf");
    await fsp.writeFile(filePath, Buffer.from("%PDF-1.4 x"));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 11 }),
      );

      assert.equal(capture.status, 409);
      assert.match((capture.body as { message?: string }).message ?? "", /sudah ada/);
      assert.equal(stubDb.notificationInserted, false);
      assert.equal(cloudSpy.destroyCalls.length, 1);
      assert.equal(cloudSpy.destroyCalls[0].publicId, "jobtrack/cvs/stub-1");
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("meneruskan error database lain ke middleware error dan tetap bersih", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb({
      insertError: { code: "ER_DBACCESS_DENIED_ERROR" },
    });
    const filePath = path.join(tempDir, "db-fail.pdf");
    await fsp.writeFile(filePath, Buffer.from("%PDF-1.4 x"));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 11 }),
      );

      assert.equal(capture.status, undefined);
      assert.equal(capture.nextError, true);
      assert.equal(cloudSpy.destroyCalls.length, 1);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("bersih aset Cloudinary walau cleanup best-effort gagal dicatat", async () => {
    const cloudSpy = stubCloudinary();
    cloudSpy.setDestroyError(new Error("destroy failed"));
    const stubDb = stubApplicationDb({
      insertError: { code: "ER_DUP_ENTRY" },
    });
    const filePath = path.join(tempDir, "cleanup-fail.pdf");
    await fsp.writeFile(filePath, Buffer.from("%PDF-1.4 x"));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 11 }),
      );

      assert.equal(capture.status, 409);
      assert.equal(cloudSpy.destroyCalls.length, 1);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
      await assertFileGone(filePath);
    }
  });

  it("lowongan tidak ditemukan → 404 tanpa menyentuh Cloudinary", async () => {
    const cloudSpy = stubCloudinary();
    const stubDb = stubApplicationDb({ jobExists: false });
    const filePath = path.join(tempDir, "no-job.pdf");
    await fsp.writeFile(filePath, Buffer.from("%PDF-1.4 x"));

    try {
      const capture = await callController(
        createApplication,
        applyRequest({ path: filePath, size: 11 }),
      );

      assert.equal(capture.status, 404);
      assert.match((capture.body as { message?: string }).message ?? "", /tidak ditemukan/);
      assert.equal(cloudSpy.uploadCalls.length, 0);
      await assertFileGone(filePath);
    } finally {
      cloudSpy.restore();
      stubDb.restore();
    }
  });
});
