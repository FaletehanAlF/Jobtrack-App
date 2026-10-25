import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createApplicationSchema } from "../validations/application.validation.js";

describe("createApplicationSchema", () => {
  it("menerima job_id angka positif", () => {
    const result = createApplicationSchema.parse({ job_id: 123 });

    assert.equal(result.job_id, 123);
  });

  it("menerima job_id dalam bentuk string angka, mengikuti pola jobIdSchema", () => {
    const result = createApplicationSchema.parse({ job_id: "123" });

    assert.equal(result.job_id, 123);
  });

  it("menolak lamaran tanpa job_id", () => {
    const result = createApplicationSchema.safeParse({});

    assert.equal(result.success, false);
  });

  it("menolak job_id nol, negatif, desimal, dan bukan angka", () => {
    for (const invalidValue of [0, -1, 1.5, "abc"]) {
      const result = createApplicationSchema.safeParse({ job_id: invalidValue });

      assert.equal(
        result.success,
        false,
        `job_id=${String(invalidValue)} seharusnya ditolak`,
      );
    }
  });

  it("tidak memakai applicant_id dari body; kolom asing dibuang tanpa mengubah job_id", () => {
    // Pemindahan applicant_id masuk melalui token JWT di controller, bukan
    // body. Schema memastikan nilai yang disusupi di body tidak dipakai.
    const result = createApplicationSchema.parse({
      job_id: 5,
      applicant_id: 999,
    });

    assert.equal(result.job_id, 5);
    assert.equal("applicant_id" in result, false);
  });
});
