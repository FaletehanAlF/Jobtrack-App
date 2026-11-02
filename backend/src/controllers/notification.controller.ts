import type { NextFunction, Request, Response } from "express";
import type { RowDataPacket } from "mysql2";
import { db } from "../config/database.js";
import {
  listNotificationsQuerySchema,
  notificationIdSchema,
} from "../validations/notification.validation.js";

interface NotificationRow extends RowDataPacket {
  id: number;
  type: string;
  message: string;
  job_id: number | null;
  application_id: number | null;
  created_at: Date | string;
  read_at: Date | string | null;
}

interface TotalRow extends RowDataPacket {
  total: number | string;
}

interface UnreadRow extends RowDataPacket {
  unread: number | string;
}

const NOTIFICATION_COLUMNS =
  "id, type, message, job_id, application_id, created_at, read_at";

function toCount(value: number | string | undefined): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function toNotification(row: NotificationRow) {
  return {
    id: row.id,
    type: row.type,
    message: row.message,
    job_id: row.job_id,
    application_id: row.application_id,
    created_at: row.created_at,
    read_at: row.read_at,
    is_read: row.read_at !== null,
  };
}

export async function listNotifications(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const queryResult = listNotificationsQuerySchema.safeParse(req.query);

  if (!queryResult.success) {
    res.status(400).json({ message: "Parameter notifikasi tidak valid" });
    return;
  }

  const { limit, offset } = queryResult.data;
  const recipientId = req.user.id;

  try {
    const [countRows] = await db.query<TotalRow[]>(
      "SELECT COUNT(*) AS total FROM notifications WHERE recipient_id = ?",
      [recipientId],
    );

    const [unreadRows] = await db.query<UnreadRow[]>(
      `SELECT COUNT(*) AS unread FROM notifications
       WHERE recipient_id = ? AND read_at IS NULL`,
      [recipientId],
    );

    const [rows] = await db.query<NotificationRow[]>(
      `SELECT ${NOTIFICATION_COLUMNS} FROM notifications
       WHERE recipient_id = ?
       ORDER BY created_at DESC, id DESC
       LIMIT ? OFFSET ?`,
      [recipientId, limit, offset],
    );

    res.status(200).json({
      notifications: rows.map(toNotification),
      total: toCount(countRows[0]?.total),
      unread: toCount(unreadRows[0]?.unread),
      limit,
      offset,
    });
  } catch (error) {
    next(error);
  }
}

export async function getUnreadNotificationCount(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  try {
    const [rows] = await db.query<UnreadRow[]>(
      `SELECT COUNT(*) AS unread FROM notifications
       WHERE recipient_id = ? AND read_at IS NULL`,
      [req.user.id],
    );

    res.status(200).json({ unread: toCount(rows[0]?.unread) });
  } catch (error) {
    next(error);
  }
}

export async function markAllNotificationsRead(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  try {
    await db.query(
      `UPDATE notifications SET read_at = NOW()
       WHERE recipient_id = ? AND read_at IS NULL`,
      [req.user.id],
    );

    res.status(200).json({ message: "Semua notifikasi ditandai sudah dibaca" });
  } catch (error) {
    next(error);
  }
}

export async function markNotificationRead(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const idResult = notificationIdSchema.safeParse(req.params.id);

  if (!idResult.success) {
    res.status(400).json({ message: "ID notifikasi tidak valid" });
    return;
  }

  const notificationId = idResult.data;
  const recipientId = req.user.id;

  try {
    await db.query(
      `UPDATE notifications SET read_at = NOW()
       WHERE id = ? AND recipient_id = ? AND read_at IS NULL`,
      [notificationId, recipientId],
    );

    const [rows] = await db.query<NotificationRow[]>(
      `SELECT ${NOTIFICATION_COLUMNS} FROM notifications
       WHERE id = ? AND recipient_id = ?
       LIMIT 1`,
      [notificationId, recipientId],
    );

    const row = rows[0];

    if (!row) {
      res.status(404).json({ message: "Notifikasi tidak ditemukan" });
      return;
    }

    res.status(200).json({ notification: toNotification(row) });
  } catch (error) {
    next(error);
  }
}