import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";

// Data pengguna yang diambil dari token.
export interface AuthUser {
  id: number;
  role: string;
}

// Menambahkan properti user ke Request, agar handler berikutnya bisa
// membaca req.user tanpa TypeScript menganggapnya tidak ada.
declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export function authenticate(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    res.status(401).json({ message: "Token tidak ditemukan" });
    return;
  }

  // Header yang diharapkan berformat: "Bearer <token>"
  const parts = authHeader.split(" ");
  const scheme = parts[0];
  const token = parts[1];

  if (scheme.toLowerCase() !== "bearer" || !token) {
    res.status(401).json({ message: "Format token tidak valid" });
    return;
  }

  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    // Sengaja error, bukan memakai secret bawaan yang bisa ditebak orang lain.
    throw new Error(
      "JWT_SECRET belum diatur. Tambahkan JWT_SECRET di backend/.env sebelum memakai middleware autentikasi.",
    );
  }

  try {
    // Melempar error jika tanda tangan salah, token kedaluwarsa, atau rusak.
    const payload = jwt.verify(token, jwtSecret);

    // Payload harus berupa objek berisi id dan role seperti saat login.
    if (typeof payload === "string") {
      res.status(401).json({ message: "Token tidak valid" });
      return;
    }

    const userId = payload.id;
    const userRole = payload.role;

    if (typeof userId !== "number" || typeof userRole !== "string") {
      res.status(401).json({ message: "Token tidak valid" });
      return;
    }

    req.user = { id: userId, role: userRole };

    // Token valid: lanjutkan ke handler berikutnya.
    next();
  } catch {
    res
      .status(401)
      .json({ message: "Token tidak valid atau sudah kedaluwarsa" });
  }
}
