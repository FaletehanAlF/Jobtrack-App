import { Router } from "express";
import { authenticate } from "../config/middleware/auth.middleware.js";
import { authorizeRoles } from "../config/middleware/authorize.middleware.js";
import {
  getRecruiterDashboard,
  listRecruiterApplicantsFiltered,
  updateApplicationStatus,
} from "../controllers/recruiter.controller.js";

// Semua endpoint di sini khusus recruiter: JWT wajib valid dan role harus
// recruiter. Kepemilikan data diverifikasi di controller memakai id dari
// token, bukan dari query/body/URL.
export const recruiterRouter = Router();

recruiterRouter.get(
  "/dashboard",
  authenticate,
  authorizeRoles("recruiter"),
  getRecruiterDashboard,
);

recruiterRouter.get(
  "/applicants",
  authenticate,
  authorizeRoles("recruiter"),
  listRecruiterApplicantsFiltered,
);

// PATCH dipakai karena hanya sebagian field (status) yang diubah.
recruiterRouter.patch(
  "/applicants/:id/status",
  authenticate,
  authorizeRoles("recruiter"),
  updateApplicationStatus,
);
