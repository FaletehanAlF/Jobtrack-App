import type { NextFunction, Request, Response } from "express";
import type { RowDataPacket } from "mysql2";
import { db } from "../config/database.js";

// Bentuk baris hasil query profil. password_hash sengaja tidak ada di sini,
// karena kolom itu memang tidak pernah diambil dari database.
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
  // Middleware authenticate sudah mengisi req.user, tapi TypeScript tetap
  // menganggapnya mungkin kosong, jadi diperiksa lebih dulu.
  if (!req.user) {
    res.status(401).json({ message: "Tidak terautentikasi" });
    return;
  }

  const userId = req.user.id;

  try {
    // Hanya kolom aman yang diambil. password_hash tidak pernah di-SELECT,
    // jadi tidak mungkin ikut terkirim ke klien.
    const [rows] = await db.query<ProfileRow[]>(
      "SELECT id, username, email, role, created_at FROM users WHERE id = ? LIMIT 1",
      [userId],
    );

    const user = rows[0];

    // Token masih valid, tetapi barisnya sudah tidak ada di database.
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
    // Kegagalan database diteruskan ke error handler, bukan diubah jadi sukses.
    next(error);
  }
}
