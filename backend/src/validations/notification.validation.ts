import { z } from "zod";

// Validasi query daftar notifikasi.
//
// Pagination dipakai agar daftar tidak pernah memuat seluruh riwayat
// sekaligus. Batas atas 100 mencegah permintaan besar yang tidak perlu.
export const listNotificationsQuerySchema = z.object({
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

// Parameter :id dari URL selalu berupa string.
export const notificationIdSchema = z.coerce.number().int().positive();

export type ListNotificationsQuery = z.infer<
  typeof listNotificationsQuerySchema
>;
