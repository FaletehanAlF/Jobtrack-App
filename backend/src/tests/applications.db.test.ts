import { describe, it, before, after } from "node:test";
import type { TestContext } from "node:test";
import assert from "node:assert/strict";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import { db } from "../config/database.js";
import {
  createApplication,
  listApplications,
} from "../controllers/application.controller.js";
import { callController, makeReq } from "./helpers.js";

// Pengujian ini menulis data ke database, jadi tidak pernah dijalankan
// otomatis. Untuk menjalankannya secara sadar (setelah migration disetujui
// dan dieksekusi pada database test):
//
//   set RUN_DB_TESTS=1 && npm run test:db
//
// Database yang dipakai tetap identitas koneksi di backend/.env. Pakai
// salinan database test, bukan database yang disepakati tidak boleh diubah.
const RUN_DB_TESTS = process.env.RUN_DB_TESTS === "1";
const SKIP_MIGRATION_MESSAGE =
  "Butuh RUN_DB_TESTS=1 dan tabel job_applications yang sudah dibuat oleh migration table-job-applications.sql.";

describe("integrasi database job_applications", {
  skip: RUN_DB_TESTS ? false : SKIP_MIGRATION_MESSAGE,
}, () => {
  // Penanda unik supaya data tester tidak bertabrakan dengan data lain maupun
  // sisa run sebelumnya yang tidak sempat dibersihkan.
  const runId = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

  let recruiterUserId = 0;
  let applicantUserId = 0;
  let otherApplicantUserId = 0;
  let jobIdA = 0;
  let jobIdB = 0;
  let dbReady = false;

  function ensureDb(t: TestContext): boolean {
    if (dbReady) return true;

    t.skip(
      "Tabel job_applications belum ada. Jalankan migration dulu (butuh persetujuan terpisah).",
    );
    return false;
  }

  before(async () => {
    try {
      await db.query("SELECT 1 FROM job_applications LIMIT 1");
      dbReady = true;
    } catch {
      // Tabel belum dibuat: migration belum dieksekusi. Semua kasus di bawah
      // dilewati dengan alasan yang jelas, bukan gagal.
      dbReady = false;
      return;
    }

    // Bersihkan sisa data tester dari run yang crash sebelumnya. FK
    // ON DELETE CASCADE menghapus jobs dan lamarannya ikut dalam satu langkah.
    await db.query<ResultSetHeader>(
      "DELETE FROM users WHERE username LIKE 'JTTEST%'",
    );

    const [recruiterInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, 'x', 'recruiter')",
      [`JTTESTREC_${runId}`, `JTTESTREC_${runId}@example.test`],
    );
    recruiterUserId = recruiterInsert.insertId;

    const [applicantInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, 'x', 'jobseeker')",
      [`JTTESTAPPL_${runId}`, `JTTESTAPPL_${runId}@example.test`],
    );
    applicantUserId = applicantInsert.insertId;

    const [otherInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, 'x', 'jobseeker')",
      [`JTTESTOTH_${runId}`, `JTTESTOTH_${runId}@example.test`],
    );
    otherApplicantUserId = otherInsert.insertId;

    const [jobAInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO jobs (recruiter_id, title, description, company, location) VALUES (?, ?, ?, ?, ?)",
      [
        recruiterUserId,
        "JT Test Lowongan A",
        "Deskripsi lowongan A untuk pengujian.",
        "JT Test Co",
        "Testville",
      ],
    );
    jobIdA = jobAInsert.insertId;

    const [jobBInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO jobs (recruiter_id, title, description, company, location) VALUES (?, ?, ?, ?, ?)",
      [
        recruiterUserId,
        "JT Test Lowongan B",
        "Deskripsi lowongan B untuk pengujian.",
        "JT Test Co",
        "Testville",
      ],
    );
    jobIdB = jobBInsert.insertId;
  });

  after(async () => {
    if (dbReady) {
      // Bersihkan data tester. CASCADE juga menghapus jobs dan lamarannya.
      await db.query<ResultSetHeader>(
        "DELETE FROM users WHERE username LIKE 'JTTEST%'",
      );
    }

    // Tutup pool supaya proses pengujian berhenti bersih.
    await db.end();
  });

  it("menolak body tanpa job_id dengan 400", async (t) => {
    if (!ensureDb(t)) return;

    const capture = await callController(
      createApplication,
      makeReq({ id: applicantUserId, role: "jobseeker" }, {}),
    );

    assert.equal(capture.status, 400);
    const body = capture.body as { errors?: Record<string, string> };
    assert.ok(body.errors?.job_id);
  });

  it("menolak job yang tidak ditemukan dengan 404", async (t) => {
    if (!ensureDb(t)) return;

    const [rows] = await db.query<RowDataPacket[]>(
      "SELECT COALESCE(MAX(id), 0) + 1 AS missingId FROM jobs",
    );
    const missingId = Number(rows[0].missingId);

    const capture = await callController(
      createApplication,
      makeReq({ id: applicantUserId, role: "jobseeker" }, { job_id: missingId }),
    );

    assert.equal(capture.status, 404);
  });

  it("lamaran pertama dibuat dengan status submitted dan applicant_id dari token, bukan body", async (t) => {
    if (!ensureDb(t)) return;

    // applicant_id dan status yang disusupi di body harus tidak berpengaruh.
    const capture = await callController(
      createApplication,
      makeReq({ id: applicantUserId, role: "jobseeker" }, {
        job_id: jobIdA,
        applicant_id: otherApplicantUserId,
        status: "rejected",
      }),
    );

    assert.equal(capture.status, 201);
    const created = (
      capture.body as {
        application: {
          id: number;
          job_id: number;
          status: string;
          created_at: string;
        };
      }
    ).application;
    assert.equal(created.job_id, jobIdA);
    assert.equal(created.status, "submitted");
    assert.ok(created.created_at);

    const [rows] = await db.query<RowDataPacket[]>(
      "SELECT applicant_id, status FROM job_applications WHERE id = ? LIMIT 1",
      [created.id],
    );
    assert.equal(rows.length, 1);
    assert.equal(Number(rows[0].applicant_id), applicantUserId);
    assert.equal(String(rows[0].status), "submitted");
  });

  it("lamaran kedua untuk lowongan yang sama saat masih submitted menghasilkan 409", async (t) => {
    if (!ensureDb(t)) return;

    const capture = await callController(
      createApplication,
      makeReq({ id: applicantUserId, role: "jobseeker" }, { job_id: jobIdA }),
    );

    assert.equal(capture.status, 409);
    const body = capture.body as { errors?: Record<string, string> };
    assert.ok(body.errors?.job_id);

    // Riwayat tidak bertambah: tetap satu baris untuk pasangan ini.
    const [rows] = await db.query<RowDataPacket[]>(
      "SELECT COUNT(*) AS total FROM job_applications WHERE applicant_id = ? AND job_id = ?",
      [applicantUserId, jobIdA],
    );
    assert.equal(Number(rows[0].total), 1);
  });

  it("request bersamaan tidak menghasilkan lebih dari satu lamaran aktif", async (t) => {
    if (!ensureDb(t)) return;

    // Lima request paralel dengan pasangan pelamar dan lowongan yang sama.
    // Constraint UNIQUE di database yang menentukan sertu atau tidaknya.
    const attempts = await Promise.all(
      Array.from({ length: 5 }, () =>
        callController(
          createApplication,
          makeReq({ id: applicantUserId, role: "jobseeker" }, { job_id: jobIdB }),
        ),
      ),
    );

    const created = attempts.filter((attempt) => attempt.status === 201);
    const conflicts = attempts.filter((attempt) => attempt.status === 409);

    assert.equal(created.length, 1);
    assert.equal(conflicts.length, 4);

    const [rows] = await db.query<RowDataPacket[]>(
      "SELECT COUNT(*) AS total FROM job_applications WHERE applicant_id = ? AND job_id = ?",
      [applicantUserId, jobIdB],
    );
    assert.equal(Number(rows[0].total), 1);
  });

  it("lamaran ulang setelah status sebelumnya rejected dapat dibuat, riwayat lama tetap ada", async (t) => {
    if (!ensureDb(t)) return;

    // Baris diubah langsung lewat SQL karena endpoint perubahan status
    // (workflow recruiter) memang belum dibuat pada tahap ini. Menyimulasikan
    // status 'rejected' yang nantinya akan diatur recruiter.
    await db.query<ResultSetHeader>(
      "UPDATE job_applications SET status = 'rejected' WHERE applicant_id = ? AND job_id = ?",
      [applicantUserId, jobIdA],
    );

    const capture = await callController(
      createApplication,
      makeReq({ id: applicantUserId, role: "jobseeker" }, { job_id: jobIdA }),
    );

    assert.equal(capture.status, 201);
    const created = (
      capture.body as { application: { id: number; status: string } }
    ).application;
    assert.equal(created.status, "submitted");

    // Riwayat tidak hilang: lamaran yang sudah ditolak masih ada di baris
    // tersendiri, ditambah lamaran baru di status submitted.
    const [rows] = await db.query<RowDataPacket[]>(
      "SELECT status FROM job_applications WHERE applicant_id = ? AND job_id = ? ORDER BY id",
      [applicantUserId, jobIdA],
    );
    const rowStatuses = rows.map((row) => String(row.status)).sort();
    assert.deepEqual(rowStatuses, ["rejected", "submitted"]);
  });

  it("jobseeker hanya melihat lamarannya sendiri, lengkap dengan ringkasan lowongan", async (t) => {
    if (!ensureDb(t)) return;

    // User lain yang belum pernah melamar tidak melihat apa pun.
    const otherList = await callController(
      listApplications,
      makeReq({ id: otherApplicantUserId, role: "jobseeker" }),
    );

    assert.equal(otherList.status, 200);
    assert.deepEqual(
      (otherList.body as { applications: unknown[] }).applications,
      [],
    );

    // Pemiliknya melihat seluruh lamannya (2 untuk Job A + 1 untuk Job B).
    const ownList = await callController(
      listApplications,
      makeReq({ id: applicantUserId, role: "jobseeker" }),
    );

    assert.equal(ownList.status, 200);
    const applications = (
      ownList.body as {
        applications: Array<{
          id: number;
          job_id: number;
          status: string;
          job: { id: number; title: string; company: string; location: string };
        }>;
      }
    ).applications;

    assert.equal(applications.length, 3);

    for (const application of applications) {
      // applicant_id tidak diekspos di respons, ringkasan lowongan selalu ada
      // karena FK dengan ON DELETE CASCADE menjamin lamaran selalu punya job.
      assert.equal("applicant_id" in application, false);
      assert.equal(
        application.job.title.startsWith("JT Test Lowongan"), true,
      );
      assert.ok(application.job.company);
    }
  });
});
