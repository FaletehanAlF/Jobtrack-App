import { Router } from "express";
import { authenticate } from "../config/middleware/auth.middleware.js";
import { authorizeRoles } from "../config/middleware/authorize.middleware.js";
import {
  listJobs,
  getJob,
  createJob,
  updateJob,
  deleteJob,
} from "../controllers/job.controller.js";

export const jobRouter = Router();

// Semua endpoint Jobs wajib login, termasuk kedua endpoint GET.
jobRouter.get("/", authenticate, listJobs);
jobRouter.get("/:id", authenticate, getJob);

// Membuat, mengubah, dan menghapus hanya untuk recruiter.
jobRouter.post("/", authenticate, authorizeRoles("recruiter"), createJob);
jobRouter.put("/:id", authenticate, authorizeRoles("recruiter"), updateJob);
jobRouter.delete("/:id", authenticate, authorizeRoles("recruiter"), deleteJob);
