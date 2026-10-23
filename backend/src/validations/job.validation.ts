import { z } from "zod";

// Validasi input lowongan. Semua schema Zod lowongan berada di file ini,
// mengikuti pola src/validations/auth.validation.ts.

export const createJobSchema = z.object({
  title: z
    .string()
    .trim()
    .min(3, "Judul minimal 3 karakter")
    .max(150, "Judul maksimal 150 karakter"),
  description: z.string().trim().min(10, "Deskripsi minimal 10 karakter"),
  company: z
    .string()
    .trim()
    .min(2, "Nama perusahaan minimal 2 karakter")
    .max(100, "Nama perusahaan maksimal 100 karakter"),
  location: z
    .string()
    .trim()
    .min(2, "Lokasi minimal 2 karakter")
    .max(100, "Lokasi maksimal 100 karakter"),
});

// PUT mengganti seluruh isi lowongan, jadi aturannya sama dengan saat membuat.
export const updateJobSchema = createJobSchema;

// Parameter :id dari URL selalu berupa string, jadi diubah ke angka dulu.
// "abc" menjadi NaN dan "1.5" menjadi 1.5, keduanya ditolak oleh int().
export const jobIdSchema = z.coerce.number().int().positive();

export type CreateJobInput = z.infer<typeof createJobSchema>;
