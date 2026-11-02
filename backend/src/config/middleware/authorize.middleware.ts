import type { NextFunction, Request, Response } from "express";

export type Role = "jobseeker" | "recruiter";

export function authorizeRoles(...allowedRoles: Role[]) {
  return function (req: Request, res: Response, next: NextFunction): void {
    const user = req.user;

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
