import type { NextFunction, Request, Response } from "express";
import type { RowDataPacket } from "mysql2";
import { db } from "../config/database.js";

interface ProfileRow extends RowDataPacket {
  id: number;
  username: string;
  email: string;
  role: string;
  created_at: Date | string;
}

export async function getMe(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const userId = req.user.id;

  try {
    const [rows] = await db.query<ProfileRow[]>(
      "SELECT id, username, email, role, created_at FROM users WHERE id = ? LIMIT 1",
      [userId],
    );

    const user = rows[0];

    if (!user) {
      res.status(404).json({ message: "Pengguna tidak ditemukan" });
      return;
    }

    res.status(200).json({
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        created_at: user.created_at,
      },
    });
  } catch (error) {
    next(error);
  }
}
