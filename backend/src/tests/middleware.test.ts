import { describe, it } from "node:test";
import assert from "node:assert/strict";
import type { AuthUser } from "../config/middleware/auth.middleware.js";
import { authorizeRoles, type Role } from "../config/middleware/authorize.middleware.js";
import { callMiddleware, makeReq } from "./helpers.js";

describe("authorizeRoles untuk endpoint lamaran (khusus jobseeker)", () => {
  it("melewatkan jobseeker ke next", () => {
    const user: AuthUser = { id: 1, role: "jobseeker" };
    const capture = callMiddleware(
      authorizeRoles("jobseeker"),
      makeReq(user),
    );

    assert.equal(capture.nextError, true);
    assert.equal(capture.status, undefined);
  });

  it("menolak recruiter dengan 403 karena endpoint ini hanya untuk jobseeker", () => {
    const user: AuthUser = { id: 2, role: "recruiter" };
    const capture = callMiddleware(
      authorizeRoles("jobseeker"),
      makeReq(user),
    );

    assert.equal(capture.nextError, undefined);
    assert.equal(capture.status, 403);
    assert.match(String((capture.body as { message?: string }).message), /jobseeker/);
  });

  it("menolak request tanpa token dengan 401", () => {
    const capture = callMiddleware(
      authorizeRoles("jobseeker"),
      makeReq(undefined),
    );

    assert.equal(capture.nextError, undefined);
    assert.equal(capture.status, 401);
  });

  it("mengizinkan kombinasi beberapa role", () => {
    const allowedRoles: Role[] = ["recruiter", "jobseeker"];

    for (const role of allowedRoles) {
      const capture = callMiddleware(
        authorizeRoles(...allowedRoles),
        makeReq({ id: 3, role }),
      );

      assert.equal(capture.nextError, true, `role ${role} seharusnya lewat`);
      assert.equal(capture.status, undefined);
    }
  });
});

describe("authorizeRoles untuk endpoint recruiter", () => {
  it("melewatkan recruiter ke next", () => {
    const user: AuthUser = { id: 2, role: "recruiter" };
    const capture = callMiddleware(
      authorizeRoles("recruiter"),
      makeReq(user),
    );

    assert.equal(capture.nextError, true);
    assert.equal(capture.status, undefined);
  });

  it("menolak jobseeker dengan 403", () => {
    const user: AuthUser = { id: 1, role: "jobseeker" };
    const capture = callMiddleware(
      authorizeRoles("recruiter"),
      makeReq(user),
    );

    assert.equal(capture.nextError, undefined);
    assert.equal(capture.status, 403);
    assert.match(
      String((capture.body as { message?: string }).message),
      /recruiter/,
    );
  });
});
