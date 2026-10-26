import writeExcelFile from "write-excel-file/node";
import type { Cell, SheetData } from "write-excel-file/node";

/**
 * Laporan Excel dibuat di backend supaya baris yang diekspor sudah difilter
 * berdasarkan identitas JWT dan kepemilikan lowongan. Frontend hanya menerima
 * byte .xlsx yang sudah diotorisasi.
 */
export const EXCEL_MIME_TYPE =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

export interface JobseekerReportRow {
  jobTitle: string;
  company: string;
  location: string;
  status: string;
  createdAt: Date | string | null;
}

export interface RecruiterReportRow {
  jobTitle: string;
  company: string;
  applicantUsername: string;
  status: string;
  createdAt: Date | string | null;
}

export class EmptyReportError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EmptyReportError";
  }
}

function textCell(value: string | null | undefined): Cell {
  // `type: String` + format teks memastikan nilai pengguna tidak pernah
  // ditafsirkan Excel sebagai formula, meskipun diawali =, +, -, atau @.
  return {
    value: value ?? "",
    type: String,
    format: "@",
  };
}

function dateCell(value: Date | string | null | undefined): Cell {
  const date = toReportDate(value);
  if (!date) return null;

  return {
    value: date,
    type: Date,
    format: "dd/mm/yyyy",
  };
}

function headerCell(value: string): Cell {
  return {
    value,
    type: String,
    fontWeight: "bold",
    backgroundColor: "#EAF2FF",
    textColor: "#102A43",
    alignVertical: "center",
  };
}

export function reportStatusLabel(status: string): string {
  switch (status) {
    case "submitted":
      return "Dikirim";
    case "rejected":
      return "Ditolak";
    default:
      return status || "Tidak diketahui";
  }
}

export function toReportDate(
  value: Date | string | null | undefined,
): Date | null {
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (typeof value === "string" && value.trim() !== "") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  return null;
}

export function buildReportFilename(
  kind: "lamaran" | "pelamar",
  date = new Date(),
): string {
  const day = date.toISOString().slice(0, 10);
  return `laporan_${kind}_${day}.xlsx`;
}

async function buildWorkbook(
  sheetName: string,
  columnWidths: number[],
  data: SheetData,
): Promise<Buffer> {
  return writeExcelFile(data, {
    sheet: sheetName,
    columns: columnWidths.map((width) => ({ width })),
    stickyRowsCount: 1,
  }).toBuffer();
}

/**
 * Laporan riwayat lamaran jobseeker. Kolom hanya berisi data yang memang
 * tersedia di tabel jobs/job_applications dan tidak menyertakan data pribadi
 * seperti password, token, atau email.
 */
export async function buildJobseekerApplicationsReport(
  rows: JobseekerReportRow[],
): Promise<Buffer> {
  if (rows.length === 0) {
    throw new EmptyReportError("Belum ada lamaran untuk diekspor.");
  }

  const data: SheetData = [
    [
      "No",
      "Judul Lowongan",
      "Perusahaan",
      "Lokasi Pekerjaan",
      "Status Lamaran",
      "Tanggal Melamar",
    ].map(headerCell),
    ...rows.map((row, index) => [
      index + 1,
      textCell(row.jobTitle),
      textCell(row.company),
      textCell(row.location),
      textCell(reportStatusLabel(row.status)),
      dateCell(row.createdAt),
    ]),
  ];

  return buildWorkbook("Lamaran", [6, 32, 24, 22, 16, 17], data);
}

/**
 * Laporan pelamar untuk recruiter. Pemanggil wajib sudah memfilter baris
 * dengan `jobs.recruiter_id` dari token; laporan ini tidak menambah data
 * pelamar selain username yang memang dikirim endpoint daftar pelamar.
 */
export async function buildRecruiterApplicantsReport(
  rows: RecruiterReportRow[],
): Promise<Buffer> {
  if (rows.length === 0) {
    throw new EmptyReportError("Belum ada pelamar untuk diekspor.");
  }

  const data: SheetData = [
    [
      "No",
      "Judul Lowongan",
      "Perusahaan",
      "Nama Pelamar",
      "Status Lamaran",
      "Tanggal Melamar",
    ].map(headerCell),
    ...rows.map((row, index) => [
      index + 1,
      textCell(row.jobTitle),
      textCell(row.company),
      textCell(row.applicantUsername),
      textCell(reportStatusLabel(row.status)),
      dateCell(row.createdAt),
    ]),
  ];

  return buildWorkbook("Pelamar", [6, 32, 24, 24, 16, 17], data);
}
