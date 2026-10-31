import { z } from "zod";

// Validasi input khusus recruiter. Semua schema berada di file ini,
// mengikuti pola src/validations/job.validation.ts.

// Query string selalu berupa string (atau tidak ada). Nilai kosong dari
// form/frontend dianggap "tidak difilter", bukan 0.
const optionalPositiveInt = z.preprocess(
  (value) =>
    value === "" || value === undefined || value === null ? undefined : value,
  z.coerce.number().int().positive().optional(),
);

// Filter daftar pelamar. Batas limit mencegah pengambilan data berlebihan;
// default 50 cukup untuk satu layar daftar pelamar.
export const recruiterApplicantsQuerySchema = z.object({
  job_id: optionalPositiveInt,
  status: z.enum(["submitted", "rejected"]).optional(),
  limit: z.preprocess(
    (value) =>
      value === "" || value === undefined || value === null ? undefined : value,
    z.coerce.number().int().min(1).max(100).default(50),
  ),
  offset: z.preprocess(
    (value) =>
      value === "" || value === undefined || value === null ? undefined : value,
    z.coerce.number().int().min(0).default(0),
  ),
});

// Status yang boleh ditetapkan recruiter.
//
// Hanya nilai yang benar-benar ada di ENUM kolom status. Status seperti
// 'interview', 'accepted', atau 'hired' sengaja tidak diterima karena
// belum ada di skema maupun alur bisnisnya.
//
// Catatan penting soal 'submitted': tabel job_applications memakai kolom
// turunan active_slot (NULL saat rejected, 1 saat lainnya) dengan
// UNIQUE(applicant_id, job_id, active_slot). Mengembalikan lamaran lama ke
// 'submitted' bisa bentrok dengan lamaran aktif yang lebih baru untuk
// lowongan yang sama; konflik itu ditangani controller sebagai 409.
const ALLOWED_STATUSES = ["submitted", "rejected"] as const;

export const updateApplicationStatusSchema = z.object({
  status: z.string().refine(
    (value) => (ALLOWED_STATUSES as readonly string[]).includes(value),
    {
      message: `Status hanya dapat diubah menjadi: ${ALLOWED_STATUSES.join(", ")}`,
    },
  ),
});

// Parameter :id dari URL selalu berupa string, jadi diubah ke angka dulu.
export const applicationIdSchema = z.coerce.number().int().positive();

export type RecruiterApplicantsQuery = z.infer<
  typeof recruiterApplicantsQuerySchema
>;
