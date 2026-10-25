import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createApplication, listApplications } from "../controllers/application.controller.js";
import { callController, makeReq } from "./helpers.js";

// Tes perilaku controller yang tidak menyentuh database, sehingga bisa dijalankan
// tanpa migration. Skema body tidak valid maupun tanpa req.user tertolak lebih
// dulu sebelum query ke database.

describe("createApplication (tanpa database)", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      createApplication,
      makeReq(undefined, { job_id: 1 }),
    );

    assert.equal(capture.status, 401);
  });

  it("mengembalikan 400 dengan pesan per field untuk body tidak valid", async () => {
    const capture = await callController(
      createApplication,
      makeReq({ id: 1, role: "jobseeker" }, { job_id: "abc" }),
    );

    assert.equal(capture.status, 400);
    const body = capture.body as { errors?: Record<string, string> };
    assert.ok(body.errors?.job_id);
  });
});

describe("listApplications (tanpa database)", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(listApplications, makeReq(undefined));

    assert.equal(capture.status, 401);
  });
});
