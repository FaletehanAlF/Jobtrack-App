import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readSheet } from "read-excel-file/node";
import {
  buildJobseekerApplicationsReport,
  buildRecruiterApplicantsReport,
  buildReportFilename,
  EmptyReportError,
  reportStatusLabel,
} from "../reports/application-report.js";

describe("laporan Excel jobseeker", () => {
  it("menghasilkan file .xlsx dengan header dan data yang benar", async () => {
    const buffer = await buildJobseekerApplicationsReport([
      {
        jobTitle: "Flutter Developer",
        company: "PT Alpha",
        location: "Jakarta",
        status: "submitted",
        createdAt: new Date(2026, 9, 21, 12),
      },
      {
        jobTitle: "Data Analyst",
        company: "PT Beta",
        location: "Bandung",
        status: "rejected",
        createdAt: new Date(2026, 9, 22, 12),
      },
    ]);

    // File .xlsx adalah arsip ZIP, sehingga selalu diawali signature "PK".
    assert.equal(buffer.subarray(0, 2).toString("utf8"), "PK");

    const rows = await readSheet(buffer);

    assert.deepEqual(rows[0], [
      "No",
      "Judul Lowongan",
      "Perusahaan",
      "Lokasi Pekerjaan",
      "Status Lamaran",
      "Tanggal Melamar",
    ]);
    assert.equal(rows.length, 3);
    assert.equal(rows[1][0], 1);
    assert.equal(rows[1][1], "Flutter Developer");
    assert.equal(rows[1][2], "PT Alpha");
    assert.equal(rows[1][3], "Jakarta");
    assert.equal(rows[1][4], "Dikirim");
    assert.ok(rows[1][5] instanceof Date);
    assert.equal(
      (rows[1][5] as Date).toISOString().slice(0, 10),
      "2026-10-21",
    );
    assert.equal(rows[2][4], "Ditolak");
  });

  it("tidak menganggap nilai pengguna berawalan formula sebagai formula", async () => {
    const payloads = [
      "=HYPERLINK(\"https://example.test\")",
      "+SUM(1,1)",
      "-2+3",
      "@SUM(A1:A2)",
    ];

    const buffer = await buildJobseekerApplicationsReport(
      payloads.map((payload, index) => ({
        jobTitle: payload,
        company: payload,
        location: payload,
        status: index === 0 ? "submitted" : "rejected",
        createdAt: null,
      })),
    );

    const rows = await readSheet(buffer);

    for (let index = 0; index < payloads.length; index += 1) {
      assert.equal(rows[index + 1][1], payloads[index]);
      assert.equal(rows[index + 1][2], payloads[index]);
      assert.equal(rows[index + 1][3], payloads[index]);
    }
  });

  it("menolak pembuatan laporan kosong", async () => {
    await assert.rejects(
      () => buildJobseekerApplicationsReport([]),
      (error: unknown) => error instanceof EmptyReportError,
    );
  });
});

describe("laporan Excel recruiter", () => {
  it("memuat nama pelamar tanpa kolom email atau data sensitif lain", async () => {
    const buffer = await buildRecruiterApplicantsReport([
      {
        jobTitle: "Backend Developer",
        company: "PT Gamma",
        applicantUsername: "budi",
        status: "submitted",
        createdAt: new Date(2026, 9, 23, 12),
      },
    ]);

    const rows = await readSheet(buffer);

    assert.deepEqual(rows[0], [
      "No",
      "Judul Lowongan",
      "Perusahaan",
      "Nama Pelamar",
      "Status Lamaran",
      "Tanggal Melamar",
    ]);
    assert.equal(rows[0].includes("Email"), false);
    assert.equal(rows[1][3], "budi");
    assert.equal(rows[1][4], "Dikirim");
    assert.equal(rows.length, 2);
  });

  it("menolak pembuatan laporan kosong", async () => {
    await assert.rejects(
      () => buildRecruiterApplicantsReport([]),
      (error: unknown) => error instanceof EmptyReportError,
    );
  });
});

describe("detail laporan", () => {
  it("memakai label status database yang didukung", () => {
    assert.equal(reportStatusLabel("submitted"), "Dikirim");
    assert.equal(reportStatusLabel("rejected"), "Ditolak");
    assert.equal(reportStatusLabel("lainnya"), "lainnya");
  });

  it("membuat nama file yang informatif dan aman", () => {
    const date = new Date("2026-10-26T12:00:00.000Z");

    assert.equal(
      buildReportFilename("lamaran", date),
      "laporan_lamaran_2026-10-26.xlsx",
    );
    assert.equal(
      buildReportFilename("pelamar", date),
      "laporan_pelamar_2026-10-26.xlsx",
    );
  });
});
