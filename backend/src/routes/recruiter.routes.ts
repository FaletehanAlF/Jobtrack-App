import { Router } from "express";
import { authenticate } from "../config/middleware/auth.middleware.js";
import { authorizeRoles } from "../config/middleware/authorize.middleware.js";
import {
  getRecruiterApplicantCv,
  getRecruiterDashboard,
  listRecruiterApplicantsFiltered,
  streamRecruiterApplicantCv,
  updateApplicationStatus,
} from "../controllers/recruiter.controller.js";

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

recruiterRouter.patch(
  "/applicants/:id/status",
  authenticate,
  authorizeRoles("recruiter"),
  updateApplicationStatus,
);

recruiterRouter.get(
  "/applicants/:id/cv/stream",
  streamRecruiterApplicantCv,
);

recruiterRouter.get(
  "/applicants/:id/cv",
  authenticate,
  authorizeRoles("recruiter"),
  getRecruiterApplicantCv,
);
