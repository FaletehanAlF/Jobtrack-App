import { Router } from "express";
import { authenticate } from "../config/middleware/auth.middleware.js";
import { authorizeRoles } from "../config/middleware/authorize.middleware.js";
import {
  createApplication,
  exportJobseekerApplications,
  exportRecruiterApplicants,
  listApplications,
  listRecruiterApplicants,
} from "../controllers/application.controller.js";

export const applicationRouter = Router();

// Endpoint jobseeker: riwayat dan ekspor hanya berisi lamaran milik pemilik
// token. Endpoint recruiter: daftar dan ekspor pelamar hanya untuk lowongan
// dengan recruiter_id dari token.
applicationRouter.get(
  "/export",
  authenticate,
  authorizeRoles("jobseeker"),
  exportJobseekerApplications,
);
applicationRouter.get(
  "/recruiter/export",
  authenticate,
  authorizeRoles("recruiter"),
  exportRecruiterApplicants,
);
applicationRouter.get(
  "/recruiter",
  authenticate,
  authorizeRoles("recruiter"),
  listRecruiterApplicants,
);
applicationRouter.get(
  "/",
  authenticate,
  authorizeRoles("jobseeker"),
  listApplications,
);
applicationRouter.post(
  "/",
  authenticate,
  authorizeRoles("jobseeker"),
  createApplication,
);
