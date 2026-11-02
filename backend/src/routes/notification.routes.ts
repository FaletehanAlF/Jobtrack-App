import { Router } from "express";
import { authenticate } from "../config/middleware/auth.middleware.js";
import {
  getUnreadNotificationCount,
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "../controllers/notification.controller.js";

export const notificationRouter = Router();

notificationRouter.get("/", authenticate, listNotifications);

notificationRouter.get(
  "/unread-count",
  authenticate,
  getUnreadNotificationCount,
);

notificationRouter.patch("/read-all", authenticate, markAllNotificationsRead);

notificationRouter.patch("/:id/read", authenticate, markNotificationRead);