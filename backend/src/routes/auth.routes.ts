import { Router } from "express";
import { register, login } from "../controllers/auth.controller.js";
import { getMe } from "../controllers/profile.controller.js";
import { authenticate } from "../middleware/auth.middleware.js";

export const authRouter = Router();

authRouter.post("/register", register);
authRouter.post("/login", login);

authRouter.get("/me", authenticate, getMe);
