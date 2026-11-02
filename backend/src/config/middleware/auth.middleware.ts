import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";

export interface AuthUser {
  id: number;
  role: string;
}

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

  const parts = authHeader.split(" ");
  const scheme = parts[0];
  const token = parts[1];

  if (scheme.toLowerCase() !== "bearer" || !token) {
    res.status(401).json({ message: "Format token tidak valid" });
    return;
  }

  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    throw new Error(
      "JWT_SECRET belum diatur. Tambahkan JWT_SECRET di backend/.env sebelum memakai middleware autentikasi.",
    );
  }

  try {
    const payload = jwt.verify(token, jwtSecret);

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

    next();
  } catch {
    res
      .status(401)
      .json({ message: "Token tidak valid atau sudah kedaluwarsa" });
  }
}
