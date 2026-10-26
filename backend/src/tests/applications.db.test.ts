import { describe, it, before, after } from "node:test";
import type { TestContext } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import dotenv from "dotenv";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
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

/**
 * ==========================================================================
 * Pengaman fail-closed untuk pengujian yang menulis data ke database
 * ==========================================================================
 * Pengujian ini membuat dan menghapus baris, jadi tidak pernah dijalankan
 * otomatis. Semua syarat berikut HARUS terpenuhi; jika salah satu gagal,
 * seluruh kasus dilewati dan TIDAK ADA satu pun query tulis yang dijalankan:
 *
 *   1. RUN_DB_TESTS=1 — pengujian tulis diaktifkan secara sadar.
 *
 *   2. DB_NAME_TESTS=<nama> — nama database test yang diizinkan secara
 *      eksplisit, mis. salinan schema seperti jobtrack_test.
 *      RUN_DB_TESTS saja tidak cukup untuk mengizinkan penulisan.
 *
 *   3. DB_NAME_TESTS berbeda dari DB_NAME di backend/.env — database
 *      development tidak diizinkan menjadi target tes meskipun disebut
 *      secara eksplisit. Nilai DB_NAME dari .env hanya untuk perbandingan
 *      dan tidak pernah dicetak ke log.
 *
 *   4. Nama database yang benar-benar terhubung diverifikasi lewat
 *      SELECT DATABASE() pada pool yang sama dengan yang dipakai controller
 *      (config/database.ts), dan HARUS sama dengan DB_NAME_TESTS.
 *      Karena controller memakai pool yang dikonfigurasi dari DB_NAME,
 *      jalankan tes dengan DB_NAME proses diarahkan ke database test:
 *
 *        # PowerShell
 *        $env:RUN_DB_TESTS  = "1"
 *        $env:DB_NAME_TESTS = "jobtrack_test"
 *        $env:DB_NAME       = "jobtrack_test"
 *        npm run test:db
 *
 *      Verifikasi ini juga menarik ketidakpastian urutan pemuatan .env oleh
 *      tsx (injected env): sampai koneksi benar-benar menunjuk database test,
 *      pengujian tetap berhenti sebelum operasi tulis apa pun.
 * ==========================================================================
 */
const RUN_DB_TESTS = process.env.RUN_DB_TESTS === "1";
const TEST_DB_NAME = process.env.DB_NAME_TESTS;
const TEST_EMAIL_DOMAIN = "@example.test";
const TEST_USERNAME_PREFIX = "JTTEST";

/**
 * Membaca DB_NAME dari isi file .env di direktori kerja (backend/.env ketika
 * dijalankan lewat npm) menggunakan parser dotenv yang sama dengan yang
 * dipakai config/database.ts. Dengan begitu komentar inline, tanda kutip,
 * prefix "export", dan aturan parsing dotenv lainnya diproses persis seperti
 * saat konfigurasi dimuat. Nilainya hanya dipakai untuk perbandingan dan
 * tidak pernah dicetak.
 *
 * Mengembalikan null bila .env tidak bisa dibaca, gagal diproses, atau tidak
 * berisi DB_NAME, supaya pemanggil dapat berperilaku fail-closed.
 */
function getEnvFileDbName(): string | null {
  try {
    const content = readFileSync(resolve(process.cwd(), ".env"), "utf8");
    const parsed = dotenv.parse(content);
    const dbName = parsed["DB_NAME"];

    if (typeof dbName !== "string") return null;

    const trimmed = dbName.trim();

    return trimmed || null;
  } catch {
    return null;
  }
}

/**
 * Identitas user tes yang berhasil dibuat. Pembersihan hanya menyasar baris
 * ini, dengan pencocokan berlapis (id + email unik + domain email tes +
 * awalan username + role). Jika salah satu INSERT gagal atau kepemilikan
 * tidak dapat dibuktikan, baris tersebut tetap tidak disentuh pembersihan.
 */
interface TestUser {
  userId: number;
  email: string;
  role: "recruiter" | "jobseeker";
}

describe("integrasi database job_applications", {
  skip: RUN_DB_TESTS
    ? false
    : "Butuh RUN_DB_TESTS=1 — pengujian database tidak dijalankan otomatis.",
}, () => {
  // Identitas unik per run; email hasilnya tidak akan sama dengan data lain.
  const runId = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  const recruiterEmail = `jttestrec_${runId}${TEST_EMAIL_DOMAIN}`;
  const otherRecruiterEmail = `jttestrec2_${runId}${TEST_EMAIL_DOMAIN}`;
  const applicantEmail = `jttestappl_${runId}${TEST_EMAIL_DOMAIN}`;
  const otherEmail = `jttestoth_${runId}${TEST_EMAIL_DOMAIN}`;

  // Alasan bawaan saat suite berjalan tetapi konfigurasi belum lengkap.
  let dbSkipReason = RUN_DB_TESTS
    ? "DB_NAME_TESTS tidak diatur. Nama database test wajib eksplisit; RUN_DB_TESTS saja tidak cukup untuk mengizinkan penulisan."
    : "Butuh RUN_DB_TESTS=1.";
  let dbReady = false;
  const testUsers: TestUser[] = [];

  let recruiterUserId = 0;
  let otherRecruiterUserId = 0;
  let applicantUserId = 0;
  let otherApplicantUserId = 0;
  let jobIdA = 0;
  let jobIdB = 0;
  // Lowongan yang dibuat lalu dihapus oleh suite ini sendiri; id-nya menjadi
  // skenario "lowongan tidak ditemukan" yang deterministik.
  let removedJobId = 0;

  function ensureDb(t: TestContext): boolean {
    if (dbReady) return true;

    t.skip(dbSkipReason);
    return false;
  }

  before(async () => {
    // Lapisan tambahan, bukan pengganti skip suite di atas: hook ini tidak
    // boleh menyiapkan fixture atau menyentuh database kecuali pengujian
    // tulis sudah diaktifkan secara eksplisit.
    if (!RUN_DB_TESTS) {
      dbSkipReason =
        "Butuh RUN_DB_TESTS=1 — fixture database tidak disiapkan.";
      return;
    }

    if (!TEST_DB_NAME) return;

    const envFileDbName = getEnvFileDbName();

    if (!envFileDbName) {
      dbSkipReason =
        "Tidak dapat memverifikasi DB_NAME dari backend/.env. Konfigurasi ambigu, pengujian dihentikan tanpa operasi tulis.";
      return;
    }

    // Database development dari .env tidak boleh dijadikan target tes,
    // walau disebut secara eksplisit lewat DB_NAME_TESTS.
    if (TEST_DB_NAME === envFileDbName) {
      dbSkipReason =
        "DB_NAME_TESTS sama dengan DB_NAME di .env (database development). Konfigurasi ambigu: nama database test harus berbeda dari database development.";
      return;
    }

    // Preflight: pool terhubung ke schema dari DB_NAME proses. Jika belum
    // diarahkan ke database test yang diizinkan, berhenti tanpa menyentuh
    // database sama sekali.
    if (process.env.DB_NAME && process.env.DB_NAME !== TEST_DB_NAME) {
      dbSkipReason = `DB_NAME proses tidak diarahkan ke database test yang diizinkan. Set DB_NAME sama dengan DB_NAME_TESTS (${TEST_DB_NAME}) saat menjalankan tes.`;
      return;
    }

    try {
      // Verifikasi database aktif lewat koneksi yang benar-benar akan dipakai
      // controller saat menulis data.
      const [rows] = await db.query<RowDataPacket[]>(
        "SELECT DATABASE() AS activeDb",
      );
      const activeDb = rows[0] ? String(rows[0].activeDb || "") : "";

      if (activeDb !== TEST_DB_NAME) {
        dbSkipReason = `Database aktif yang benar-benar terhubung (${activeDb || "tidak diketahui"}) bukan database test yang diizinkan (${TEST_DB_NAME}). Pengujian berhenti tanpa operasi tulis.`;
        return;
      }
    } catch {
      // Koneksi gagal: jangan lanjut ke penulisan apa pun.
      dbSkipReason =
        "Koneksi database gagal atau nama database aktif tidak dapat diverifikasi.";
      return;
    }

    try {
      // Cek keberadaan tabel (hanya baca) setelah semua syarat lolos.
      await db.query("SELECT 1 FROM job_applications LIMIT 1");
    } catch {
      dbSkipReason =
        "Tabel job_applications belum ada. Jalankan migration table-job-applications.sql dulu (butuh persetujuan terpisah).";
      return;
    }

    dbReady = true;

    // ---- Fixture (semua query di bawah sudah terverifikasi menulis ke ----
    // ---- database test yang diizinkan secara eksplisit)              ----

    const [recruiterInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, 'x', 'recruiter')",
      [`${TEST_USERNAME_PREFIX}REC_${runId}`, recruiterEmail],
    );
    recruiterUserId = recruiterInsert.insertId;
    testUsers.push({
      userId: recruiterUserId,
      email: recruiterEmail,
      role: "recruiter",
    });

    // Recruiter kedua sengaja tidak memiliki lowongan. Dipakai untuk
    // memastikan filter kepemilikan tidak membocorkan pelamar recruiter lain.
    const [otherRecruiterInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, 'x', 'recruiter')",
      [`${TEST_USERNAME_PREFIX}REC2_${runId}`, otherRecruiterEmail],
    );
    otherRecruiterUserId = otherRecruiterInsert.insertId;
    testUsers.push({
      userId: otherRecruiterUserId,
      email: otherRecruiterEmail,
      role: "recruiter",
    });

    const [applicantInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, 'x', 'jobseeker')",
      [`${TEST_USERNAME_PREFIX}APPL_${runId}`, applicantEmail],
    );
    applicantUserId = applicantInsert.insertId;
    testUsers.push({
      userId: applicantUserId,
      email: applicantEmail,
      role: "jobseeker",
    });

    const [otherInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, 'x', 'jobseeker')",
      [`${TEST_USERNAME_PREFIX}OTH_${runId}`, otherEmail],
    );
    otherApplicantUserId = otherInsert.insertId;
    testUsers.push({
      userId: otherApplicantUserId,
      email: otherEmail,
      role: "jobseeker",
    });

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

    // Skenerio "lowongan tidak ditemukan" dibuat deterministik: lowungan
    // milik suite ini sendiri dibuat lalu segera dihapus, dengan pencocokan
    // id + pemilik + judul supaya baris yang dihapus jelas miliknya.
    const [removedJobInsert] = await db.query<ResultSetHeader>(
      "INSERT INTO jobs (recruiter_id, title, description, company, location) VALUES (?, ?, ?, ?, ?)",
      [
        recruiterUserId,
        "JT Test Lowongan Dihapus",
        "Deskripsi lowongan yang segera dihapus untuk skenario tidak ditemukan.",
        "JT Test Co",
        "Testville",
      ],
    );
    removedJobId = removedJobInsert.insertId;

    const [removeResult] = await db.query<ResultSetHeader>(
      "DELETE FROM jobs WHERE id = ? AND recruiter_id = ? AND title = ?",
      [removedJobId, recruiterUserId, "JT Test Lowongan Dihapus"],
    );

    if (removeResult.affectedRows !== 1) {
      // Skenario 404 tidak valid; berhenti dengan alasan jelas, jangan
      // melanjutkan pengujian dengan data yang tidak bisa dijamin.
      dbReady = false;
      dbSkipReason =
        "Gagal menyiapkan lowongan untuk skenario tidak ditemukan. Pengujian dilewati.";
      return;
    }
  });

  after(async () => {
    // Pembersihan HANYA menyasar user yang benar-benar dibuat run ini:
    //   - id persis dari insertId saat INSERT-nya berhasil (baris dengan
    //     insert gagal tidak pernah tercatat, jadi tidak akan dihapus),
    //   - email unik per run yang sama dengan yang dipasang saat INSERT
    //     (kolom email bersifat UNIQUE di schema users),
    //   - domain email khusus tes,
    //   - awalan username identitas tes,
    //   - role yang memang dipasang saat INSERT.
    // Kepemilikan yang tidak terbukti tidak dipindai maupun dihapus.
    for (const user of testUsers) {
      const [deleteResult] = await db.query<ResultSetHeader>(
        "DELETE FROM users WHERE id = ? AND email = ? AND email LIKE ? AND username LIKE ? AND role = ?",
        [
          user.userId,
          user.email,
          `%${TEST_EMAIL_DOMAIN}`,
          `${TEST_USERNAME_PREFIX}%`,
          user.role,
        ],
      );

      if (deleteResult.affectedRows !== 1) {
        console.warn(
          `[cleanup] user tes id=${user.userId} tidak terhapus bersih (affectedRows=${deleteResult.affectedRows}); sisa datanya harus dinilai manual`,
        );
      }
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

    // id lowongan milik suite ini yang dibuat lalu dihapus di before(); tidak
    // bergantung pada MAX(id)+1 dan selalu aman terhadap data milik orang lain.
    const capture = await callController(
      createApplication,
      makeReq({ id: applicantUserId, role: "jobseeker" }, { job_id: removedJobId }),
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
    // Constraint UNIQUE di database yang menentukan silang atau tidaknya.
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

  it("recruiter hanya melihat pelamar dari lowongan miliknya", async (t) => {
    if (!ensureDb(t)) return;

    const ownCapture = await callController(
      listRecruiterApplicants,
      makeReq({ id: recruiterUserId, role: "recruiter" }),
    );

    assert.equal(ownCapture.status, 200);
    const ownApplicants = (
      ownCapture.body as {
        applicants: Array<{
          status: string;
          applicant: Record<string, unknown>;
          job: { title: string };
        }>;
      }
    ).applicants;

    assert.equal(ownApplicants.length, 3);
    for (const applicant of ownApplicants) {
      assert.equal(
        applicant.job.title.startsWith("JT Test Lowongan"),
        true,
      );
      assert.equal(typeof applicant.applicant.username, "string");
      assert.equal("email" in applicant.applicant, false);
    }

    // Recruiter lain tidak memiliki lowongan, sehingga harus menerima daftar
    // kosong meskipun ada lamaran milik recruiter pertama di database.
    const otherCapture = await callController(
      listRecruiterApplicants,
      makeReq({ id: otherRecruiterUserId, role: "recruiter" }),
    );

    assert.equal(otherCapture.status, 200);
    assert.deepEqual(
      (otherCapture.body as { applicants: unknown[] }).applicants,
      [],
    );
  });

  it("ekspor jobseeker hanya memuat lamaran miliknya dan aman untuk data kosong", async (t) => {
    if (!ensureDb(t)) return;

    const ownCapture = await callController(
      exportJobseekerApplications,
      makeReq({ id: applicantUserId, role: "jobseeker" }),
    );

    assert.equal(ownCapture.status, 200);
    assert.match(
      ownCapture.headers?.["content-type"] ?? "",
      /spreadsheetml\.sheet/,
    );
    assert.match(
      ownCapture.headers?.["content-disposition"] ?? "",
      /laporan_lamaran_\d{4}-\d{2}-\d{2}\.xlsx/,
    );
    assert.ok(ownCapture.buffer);

    const rows = await readSheet(ownCapture.buffer);
    assert.equal(rows.length, 4); // header + 3 lamaran
    for (const row of rows.slice(1)) {
      assert.equal(
        String(row[1]).startsWith("JT Test Lowongan"),
        true,
      );
    }

    const otherCapture = await callController(
      exportJobseekerApplications,
      makeReq({ id: otherApplicantUserId, role: "jobseeker" }),
    );

    assert.equal(otherCapture.status, 404);
    assert.equal(otherCapture.buffer, undefined);
  });

  it("ekspor recruiter hanya memuat pelamar dari lowongan miliknya", async (t) => {
    if (!ensureDb(t)) return;

    const ownCapture = await callController(
      exportRecruiterApplicants,
      makeReq({ id: recruiterUserId, role: "recruiter" }),
    );

    assert.equal(ownCapture.status, 200);
    assert.match(
      ownCapture.headers?.["content-disposition"] ?? "",
      /laporan_pelamar_\d{4}-\d{2}-\d{2}\.xlsx/,
    );
    assert.ok(ownCapture.buffer);

    const rows = await readSheet(ownCapture.buffer);
    assert.equal(rows.length, 4); // header + 3 pelamar
    assert.equal(rows[0].includes("Email"), false);
    for (const row of rows.slice(1)) {
      assert.equal(
        String(row[1]).startsWith("JT Test Lowongan"),
        true,
      );
      assert.equal(
        String(row[3]).startsWith(TEST_USERNAME_PREFIX),
        true,
      );
    }

    const otherCapture = await callController(
      exportRecruiterApplicants,
      makeReq({ id: otherRecruiterUserId, role: "recruiter" }),
    );

    assert.equal(otherCapture.status, 404);
    assert.equal(otherCapture.buffer, undefined);
  });
});
