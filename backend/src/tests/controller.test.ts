import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readSheet } from "read-excel-file/node";
import { db } from "../config/database.js";
import {
  createApplication,
  exportJobseekerApplications,
  exportRecruiterApplicants,
  listApplications,
  listRecruiterApplicants,
} from "../controllers/application.controller.js";
import { callController, makeReq } from "./helpers.js";

// Tes perilaku controller yang tidak menyentuh database, sehingga bisa dijalankan
// tanpa migration. Skema body tidak valid maupun tanpa req.user tertolak lebih
// dulu sebelum query ke database.

type QueryResult = [unknown[], unknown];

function stubDbQuery(
  handler: (sql: string, params?: unknown[]) => Promise<QueryResult>,
): () => void {
  const pool = db as unknown as {
    query: (sql: string, params?: unknown[]) => Promise<QueryResult>;
  };
  const originalQuery = pool.query;
  pool.query = handler;

  return () => {
    pool.query = originalQuery;
  };
}

const recruiterApplicantRow = {
  id: 9,
  status: "submitted",
  created_at: new Date(2026, 9, 23, 12),
  job_id: 3,
  job_title: "Backend Developer",
  job_company: "PT Gamma",
  job_location: "Jakarta",
  applicant_username: "budi",
};

const jobseekerApplicationRow = {
  id: 11,
  job_id: 4,
  status: "rejected",
  created_at: new Date(2026, 9, 21, 12),
  updated_at: new Date(2026, 9, 21, 12),
  job_title: "Flutter Developer",
  job_company: "PT Alpha",
  job_location: "Bandung",
};

describe("createApplication (tanpa database)", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      createApplication,
      makeReq(undefined, { job_id: 1 }),
    );

    assert.equal(capture.status, 401);
  });

  it("mengembalikan 400 dengan pesan per field untuk body tidak valid", async () => {
    const capture = await callController(
      createApplication,
      makeReq({ id: 1, role: "jobseeker" }, { job_id: "abc" }),
    );

    assert.equal(capture.status, 400);
    const body = capture.body as { errors?: Record<string, string> };
    assert.ok(body.errors?.job_id);
  });
});

describe("listApplications (tanpa database)", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(listApplications, makeReq(undefined));

    assert.equal(capture.status, 401);
  });
});

describe("endpoint laporan (tanpa database)", () => {
  it("menolak request tanpa token pada semua endpoint laporan", async () => {
    const captures = await Promise.all([
      callController(exportJobseekerApplications, makeReq(undefined)),
      callController(listRecruiterApplicants, makeReq(undefined)),
      callController(exportRecruiterApplicants, makeReq(undefined)),
    ]);

    for (const capture of captures) {
      assert.equal(capture.status, 401);
    }
  });

  it("jobseeker hanya memakai applicant_id dari token untuk ekspor", async () => {
    let capturedSql = "";
    let capturedParams: unknown[] = [];
    const restore = stubDbQuery(async (sql, params) => {
      capturedSql = sql;
      capturedParams = params ?? [];
      return [[jobseekerApplicationRow], []];
    });

    try {
      const capture = await callController(
        exportJobseekerApplications,
        makeReq({ id: 7, role: "jobseeker" }),
      );

      assert.equal(capture.status, 200);
      assert.match(
        capture.headers?.["content-type"] ?? "",
        /spreadsheetml\.sheet/,
      );
      assert.match(
        capture.headers?.["content-disposition"] ?? "",
        /laporan_lamaran_\d{4}-\d{2}-\d{2}\.xlsx/,
      );
      assert.match(capturedSql, /a\.applicant_id = \?/);
      assert.deepEqual(capturedParams, [7]);

      assert.ok(capture.buffer);
      const rows = await readSheet(capture.buffer);
      assert.equal(rows[1][1], "Flutter Developer");
      assert.equal(rows[1][4], "Ditolak");
    } finally {
      restore();
    }
  });

  it("recruiter hanya memakai recruiter_id dari token dan tidak menerima email", async () => {
    let capturedSql = "";
    let capturedParams: unknown[] = [];
    const restore = stubDbQuery(async (sql, params) => {
      capturedSql = sql;
      capturedParams = params ?? [];
      return [[recruiterApplicantRow], []];
    });

    try {
      const capture = await callController(
        listRecruiterApplicants,
        makeReq({ id: 42, role: "recruiter" }),
      );

      assert.equal(capture.status, 200);
      assert.match(capturedSql, /j\.recruiter_id = \?/);
      assert.deepEqual(capturedParams, [42]);

      const applicants = (
        capture.body as {
          applicants: Array<{
            status: string;
            applicant: Record<string, unknown>;
            job: { title: string };
          }>;
        }
      ).applicants;

      assert.equal(applicants.length, 1);
      assert.equal(applicants[0].job.title, "Backend Developer");
      assert.deepEqual(applicants[0].applicant, { username: "budi" });
      assert.equal("email" in applicants[0].applicant, false);
    } finally {
      restore();
    }
  });

  it("ekspor recruiter memakai filter kepemilikan dan menghasilkan .xlsx", async () => {
    let capturedSql = "";
    let capturedParams: unknown[] = [];
    const restore = stubDbQuery(async (sql, params) => {
      capturedSql = sql;
      capturedParams = params ?? [];
      return [[recruiterApplicantRow], []];
    });

    try {
      const capture = await callController(
        exportRecruiterApplicants,
        makeReq({ id: 99, role: "recruiter" }),
      );

      assert.equal(capture.status, 200);
      assert.match(capturedSql, /j\.recruiter_id = \?/);
      assert.deepEqual(capturedParams, [99]);
      assert.match(
        capture.headers?.["content-disposition"] ?? "",
        /laporan_pelamar_\d{4}-\d{2}-\d{2}\.xlsx/,
      );

      assert.ok(capture.buffer);
      const rows = await readSheet(capture.buffer);
      assert.equal(rows[0].includes("Email"), false);
      assert.equal(rows[1][3], "budi");
      assert.equal(rows[1][4], "Dikirim");
    } finally {
      restore();
    }
  });

  it("ekspor data kosong ditolak tanpa membuat file palsu", async () => {
    const restore = stubDbQuery(async () => [[], []]);

    try {
      const jobseekerCapture = await callController(
        exportJobseekerApplications,
        makeReq({ id: 1, role: "jobseeker" }),
      );
      const recruiterCapture = await callController(
        exportRecruiterApplicants,
        makeReq({ id: 2, role: "recruiter" }),
      );

      assert.equal(jobseekerCapture.status, 404);
      assert.equal(recruiterCapture.status, 404);
      assert.equal(jobseekerCapture.buffer, undefined);
      assert.equal(recruiterCapture.buffer, undefined);
      assert.match(
        String((jobseekerCapture.body as { message?: string }).message),
        /Belum ada lamaran/,
      );
      assert.match(
        String((recruiterCapture.body as { message?: string }).message),
        /Belum ada pelamar/,
      );
    } finally {
      restore();
    }
  });

  it("kegagalan database diteruskan ke error handler", async () => {
    const restore = stubDbQuery(async () => {
      throw new Error("database unavailable");
    });

    try {
      const capture = await callController(
        exportJobseekerApplications,
        makeReq({ id: 1, role: "jobseeker" }),
      );

      assert.equal(capture.status, undefined);
      assert.equal(capture.nextError, true);
    } finally {
      restore();
    }
  });
});
