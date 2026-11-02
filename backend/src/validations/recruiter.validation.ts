import { z } from "zod";


const optionalPositiveInt = z.preprocess(
  (value) =>
    value === "" || value === undefined || value === null ? undefined : value,
  z.coerce.number().int().positive().optional(),
);

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

const ALLOWED_STATUSES = ["submitted", "rejected"] as const;

export const updateApplicationStatusSchema = z.object({
  status: z.string().refine(
    (value) => (ALLOWED_STATUSES as readonly string[]).includes(value),
    {
      message: `Status hanya dapat diubah menjadi: ${ALLOWED_STATUSES.join(", ")}`,
    },
  ),
});

export const applicationIdSchema = z.coerce.number().int().positive();

export type RecruiterApplicantsQuery = z.infer<
  typeof recruiterApplicantsQuerySchema
>;
