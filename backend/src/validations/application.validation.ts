import { z } from "zod";


export const createApplicationSchema = z.object({
  job_id: z.coerce.number().int().positive(),
});

export type CreateApplicationInput = z.infer<typeof createApplicationSchema>;
