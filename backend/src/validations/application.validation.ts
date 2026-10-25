import { z } from "zod";

// Validasi input lamaran. Semua schema Zod lamaran berada di file ini,
// mengikuti pola src/validations/job.validation.ts.

// Body POST /api/applications hanya menerima job_id. applicant_id selalu
// diambil dari token JWT di controller, tidak pernah dari body, supaya
// tidak bisa dipalsukan oleh pengguna lain.
export const createApplicationSchema = z.object({
  job_id: z.coerce.number().int().positive(),
});

export type CreateApplicationInput = z.infer<typeof createApplicationSchema>;
