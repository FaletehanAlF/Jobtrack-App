import type { NextFunction, Request, Response } from "express";

// Role yang dikenal aplikasi, mengikuti kolom ENUM pada tabel users.
// Ditulis sebagai union agar salah ketik seperti "recruter" ditolak TypeScript.
export type Role = "jobseeker" | "recruiter";

export function authorizeRoles(...allowedRoles: Role[]) {
  // Fungsi ini mengembalikan middleware, supaya pemakaiannya bisa:
  // authorizeRoles("recruiter") lalu dipasang langsung di route.
  return function (req: Request, res: Response, next: NextFunction): void {
    const user = req.user;

    // Middleware ini hanya memeriksa, tidak memverifikasi token.
    // Jadi kalau req.user kosong, artinya authenticate belum dijalankan.
    if (!user) {
      res.status(401).json({ message: "Tidak terautentikasi" });
      return;
    }

    const isAllowed = allowedRoles.some(
      (allowedRole) => allowedRole === user.role,
    );

    if (!isAllowed) {
      res.status(403).json({
        message: `Akses ditolak. Endpoint ini hanya untuk role: ${allowedRoles.join(", ")}`,
      });
      return;
    }

    next();
  };
}
