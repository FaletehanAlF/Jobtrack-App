import { Router } from "express";
import { authenticate } from "../middleware/auth.middleware.js";
import { authorizeRoles } from "../middleware/authorize.middleware.js";
import {
  createApplication,
  listApplications,
} from "../controllers/application.controller.js";

export const applicationRouter = Router();

// Semua endpoint lamaran wajib login dan hanya untuk jobseeker.
// Endpoint recruiter (daftar pelamar untuk lowongan miliknya) dan perubahan
// status belum dibuat pada tahap ini, sesuai keputusan produk.
applicationRouter.post(
  "/",
  authenticate,
  authorizeRoles("jobseeker"),
  createApplication,
);
applicationRouter.get(
  "/",
  authenticate,
  authorizeRoles("jobseeker"),
  listApplications,
);
