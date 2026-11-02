import { Router } from "express";
import { authenticate } from "../config/middleware/auth.middleware.js";
import { authorizeRoles } from "../config/middleware/authorize.middleware.js";
import { handleCvUpload } from "../config/middleware/upload.middleware.js";
import {
  createApplication,
  exportJobseekerApplications,
  exportRecruiterApplicants,
  listApplications,
  listRecruiterApplicants,
} from "../controllers/application.controller.js";

export const applicationRouter = Router();

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
  handleCvUpload,
  createApplication,
);
