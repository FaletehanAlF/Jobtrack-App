import type { NextFunction, Request, Response } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import type { ZodError } from "zod";
import type { ResultSetHeader, RowDataPacket } from "mysql2";
import { db } from "../config/database.js";
import { registerSchema, loginSchema } from "../validations/auth.validation.js";

const DEFAULT_ROLE = "jobseeker";
const BCRYPT_ROUNDS = 10;
const TOKEN_EXPIRES_IN = "7d";

interface UserRow extends RowDataPacket {
  id: number;
  username: string;
  email: string;
  role: string;
  created_at: Date | string;
}

interface UserWithPasswordRow extends UserRow {
  password_hash: string;
}

function getFieldErrors(error: ZodError): Record<string, string> {
  const messages: Record<string, string> = {};

  for (const issue of error.issues) {
    const field = issue.path[0];

    if (typeof field !== "string" || field in messages) continue;

    messages[field] = issue.message;
  }

  return messages;
}

export async function register(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const result = registerSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      message: "Data registrasi tidak valid",
      errors: getFieldErrors(result.error),
    });
    return;
  }

  const username = result.data.username;
  const email = result.data.email;
  const password = result.data.password;

  try {
    const [existingUsers] = await db.query<RowDataPacket[]>(
      "SELECT id FROM users WHERE email = ? LIMIT 1",
      [email],
    );

    if (existingUsers.length > 0) {
      res.status(409).json({
        message: "Email sudah terdaftar",
        errors: { email: "Email sudah terdaftar" },
      });
      return;
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    const [insertResult] = await db.query<ResultSetHeader>(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)",
      [username, email, passwordHash, DEFAULT_ROLE],
    );

    const [rows] = await db.query<UserRow[]>(
      "SELECT id, username, email, role, created_at FROM users WHERE id = ? LIMIT 1",
      [insertResult.insertId],
    );
    const user = rows[0];

    if (!user) {
      res.status(500).json({ message: "Gagal mengambil data pengguna" });
      return;
    }

    res.status(201).json({
      message: "Registrasi berhasil",
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        created_at: user.created_at,
      },
    });
  } catch (error) {
    const databaseError = error as { code?: string };

    if (databaseError.code === "ER_DUP_ENTRY") {
      res.status(409).json({
        message: "Email sudah terdaftar",
        errors: { email: "Email sudah terdaftar" },
      });
      return;
    }

    next(error);
  }
}

export async function login(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const result = loginSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      message: "Data login tidak valid",
      errors: getFieldErrors(result.error),
    });
    return;
  }

  const email = result.data.email;
  const password = result.data.password;

  try {
    const [rows] = await db.query<UserWithPasswordRow[]>(
      "SELECT id, username, email, password_hash, role, created_at FROM users WHERE email = ? LIMIT 1",
      [email],
    );
    const user = rows[0];

    const wrongCredentialsMessage = "Email atau password salah";

    if (!user) {
      res.status(401).json({ message: wrongCredentialsMessage });
      return;
    }

    const passwordMatches = await bcrypt.compare(password, user.password_hash);

    if (!passwordMatches) {
      res.status(401).json({ message: wrongCredentialsMessage });
      return;
    }

    const jwtSecret = process.env.JWT_SECRET;

    if (!jwtSecret) {
      throw new Error(
        "JWT_SECRET belum diatur. Tambahkan JWT_SECRET di backend/.env sebelum memakai endpoint login.",
      );
    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      jwtSecret,
      { expiresIn: TOKEN_EXPIRES_IN },
    );

    res.status(200).json({
      message: "Login berhasil",
      token,
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
