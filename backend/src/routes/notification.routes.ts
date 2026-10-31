import { Router } from "express";
import { authenticate } from "../config/middleware/auth.middleware.js";
import {
  getUnreadNotificationCount,
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "../controllers/notification.controller.js";

// Semua endpoint notifikasi wajib login. Tidak ada authorizeRoles di sini
// karena jobseeker dan recruiter sama-sama punya notifikasi; pemisahan data
// dilakukan lewat recipient_id dari token di controller.
export const notificationRouter = Router();

notificationRouter.get("/", authenticate, listNotifications);

notificationRouter.get(
  "/unread-count",
  authenticate,
  getUnreadNotificationCount,
);

// Rute statis "read-all" didaftarkan SEBELUM "/:id/read"; kalau urutannya
// terbalik, "read-all" akan tertangkap sebagai :id dan ditolak sebagai
// "ID notifikasi tidak valid".
notificationRouter.patch("/read-all", authenticate, markAllNotificationsRead);

notificationRouter.patch("/:id/read", authenticate, markNotificationRead);