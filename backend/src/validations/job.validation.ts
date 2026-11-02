import { z } from "zod";


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

export const updateJobSchema = createJobSchema;

export const jobIdSchema = z.coerce.number().int().positive();

export type CreateJobInput = z.infer<typeof createJobSchema>;
