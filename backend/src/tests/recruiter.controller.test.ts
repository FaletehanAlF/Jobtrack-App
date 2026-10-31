import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { db } from "../config/database.js";
import {
  getRecruiterDashboard,
  listRecruiterApplicantsFiltered,
  updateApplicationStatus,
} from "../controllers/recruiter.controller.js";
import { callController, makeReq } from "./helpers.js";

// Tes perilaku endpoint recruiter tanpa menyentuh database: query di-stub,
// sehingga yang diuji adalah aturan otorisasi dan bentuk query yang dipakai.
//
// Kepemilikan data diuji lewat parameter query yang benar-benar dikirim ke
// database: recruiter_id HARUS berasal dari token (req.user.id), dan setiap
// query wajib membawa syarat kepemilikan itu.

// mysql2 mengembalikan [rows, fields] untuk SELECT dan [ResultSetHeader, fields]
// untuk UPDATE. Stub di bawah menampung keduanya.
type QueryResult = [unknown, unknown];

interface CapturedQuery {
  sql: string;
  params: unknown[];
}

function stubDbQuery(
  handler: (sql: string, params?: unknown[]) => Promise<QueryResult>,
): { captured: CapturedQuery[]; restore: () => void } {
  const pool = db as unknown as {
    query: (sql: string, params?: unknown[]) => Promise<QueryResult>;
  };
  const originalQuery = pool.query;
  const captured: CapturedQuery[] = [];

  pool.query = (sql: string, params?: unknown[]) => {
    captured.push({ sql, params: params ?? [] });
    return handler(sql, params);
  };

  return {
    captured,
    restore: () => {
      pool.query = originalQuery;
    },
  };
}

// req.query selalu berupa string di Express. Helper makeReq hanya mengisi
// user dan body, jadi query ditambahkan lewat cast.
function makeRecruiterReq(
  user: { id: number; role: string } | undefined,
  options: { body?: unknown; query?: Record<string, string>; params?: Record<string, string> } = {},
): Parameters<typeof callController>[1] {
  const req = makeReq(user, options.body) as unknown as {
    query?: Record<string, string>;
    params?: Record<string, string>;
  };
  req.query = options.query ?? {};
  req.params = options.params ?? {};
  return req as Parameters<typeof callController>[1];
}

const recruiterDashboardRow = {
  id: 3,
  title: "Backend Developer",
  company: "PT Gamma",
  location: "Jakarta",
  created_at: new Date(2026, 9, 20, 12),
  applicant_count: "4",
  submitted_count: "3",
  rejected_count: "1",
};

const applicantRow = {
  id: 9,
  status: "submitted",
  created_at: new Date(2026, 9, 23, 12),
  job_id: 3,
  job_title: "Backend Developer",
  job_company: "PT Gamma",
  job_location: "Jakarta",
  applicant_username: "budi",
};

describe("GET /api/recruiter/dashboard", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      getRecruiterDashboard,
      makeRecruiterReq(undefined),
    );

    assert.equal(capture.status, 401);
  });

  it("memakai recruiter_id dari token, bukan dari query", async () => {
    const { captured, restore } = stubDbQuery(async () => [
      [recruiterDashboardRow],
      [],
    ]);

    try {
      // Query berisi recruiter_id milik orang lain: harus diabaikan.
      const capture = await callController(
        getRecruiterDashboard,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { query: { recruiter_id: "999" } },
        ),
      );

      assert.equal(capture.status, 200);
      assert.match(captured[0].sql, /j\.recruiter_id = \?/);
      assert.deepEqual(captured[0].params, [42]);
      assert.equal(
        captured[0].params.includes(999),
        false,
        "recruiter_id dari query tidak boleh dipakai",
      );
    } finally {
      restore();
    }
  });

  it("menghitung statistik dari hasil agregasi milik recruiter itu saja", async () => {
    const { restore } = stubDbQuery(async () => [[recruiterDashboardRow], []]);

    try {
      const capture = await callController(
        getRecruiterDashboard,
        makeRecruiterReq({ id: 42, role: "recruiter" }),
      );

      assert.equal(capture.status, 200);
      const body = capture.body as {
        stats: {
          jobs: number;
          applicants: number;
          submitted: number;
          rejected: number;
        };
        jobs: Array<{ applicant_count: number; submitted_count: number }>;
      };

      assert.deepEqual(body.stats, {
        jobs: 1,
        applicants: 4,
        submitted: 3,
        rejected: 1,
      });
      // COUNT dari mysql2 bisa berupa string; respons harus angka.
      assert.equal(body.jobs[0].applicant_count, 4);
      assert.equal(body.jobs[0].submitted_count, 3);
    } finally {
      restore();
    }
  });

  it("lowongan tanpa pelamar tetap dihitung dengan angka 0", async () => {
    const { restore } = stubDbQuery(async () => [
      [
        {
          ...recruiterDashboardRow,
          applicant_count: "0",
          submitted_count: "0",
          rejected_count: "0",
        },
      ],
      [],
    ]);

    try {
      const capture = await callController(
        getRecruiterDashboard,
        makeRecruiterReq({ id: 42, role: "recruiter" }),
      );

      const body = capture.body as {
        stats: { jobs: number; applicants: number };
        jobs: Array<{ applicant_count: number }>;
      };

      assert.equal(body.stats.jobs, 1);
      assert.equal(body.stats.applicants, 0);
      assert.equal(body.jobs[0].applicant_count, 0);
    } finally {
      restore();
    }
  });
});

describe("GET /api/recruiter/applicants", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      listRecruiterApplicantsFiltered,
      makeRecruiterReq(undefined),
    );

    assert.equal(capture.status, 401);
  });

  it("selalu membatasi hasil dengan kepemilikan lowongan", async () => {
    const { captured, restore } = stubDbQuery(async (sql) => {
      if (/COUNT\(\*\)/.test(sql)) return [[{ total: "1" }], []];
      return [[applicantRow], []];
    });

    try {
      const capture = await callController(
        listRecruiterApplicantsFiltered,
        makeRecruiterReq({ id: 42, role: "recruiter" }),
      );

      assert.equal(capture.status, 200);

      for (const query of captured) {
        assert.match(query.sql, /j\.recruiter_id = \?/);
        assert.equal(query.params[0], 42);
      }
    } finally {
      restore();
    }
  });

  it("menerapkan filter job_id dan status sebagai parameter query", async () => {
    const { captured, restore } = stubDbQuery(async (sql) => {
      if (/COUNT\(\*\)/.test(sql)) return [[{ total: "1" }], []];
      return [[applicantRow], []];
    });

    try {
      const capture = await callController(
        listRecruiterApplicantsFiltered,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { query: { job_id: "3", status: "submitted" } },
        ),
      );

      assert.equal(capture.status, 200);

      const listQuery = captured.find((query) => /LIMIT \? OFFSET \?/.test(query.sql));
      assert.ok(listQuery);
      assert.match(listQuery.sql, /a\.job_id = \?/);
      assert.match(listQuery.sql, /a\.status = \?/);
      // Urutan parameter: recruiter_id, job_id, status, limit, offset.
      assert.deepEqual(listQuery.params, [42, 3, "submitted", 50, 0]);
    } finally {
      restore();
    }
  });

  it("menolak filter status di luar nilai yang didukung database", async () => {
    const { restore } = stubDbQuery(async () => [[], []]);

    try {
      const capture = await callController(
        listRecruiterApplicantsFiltered,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { query: { status: "hired" } },
        ),
      );

      assert.equal(capture.status, 400);
      const body = capture.body as { errors?: Record<string, string> };
      assert.ok(body.errors?.status);
    } finally {
      restore();
    }
  });

  it("menolak limit di atas batas maksimum", async () => {
    const { restore } = stubDbQuery(async () => [[], []]);

    try {
      const capture = await callController(
        listRecruiterApplicantsFiltered,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { query: { limit: "5000" } },
        ),
      );

      assert.equal(capture.status, 400);
    } finally {
      restore();
    }
  });

  it("mengembalikan total dan pagination untuk halaman berikutnya", async () => {
    const { restore } = stubDbQuery(async (sql) => {
      if (/COUNT\(\*\)/.test(sql)) return [[{ total: "37" }], []];
      return [[applicantRow], []];
    });

    try {
      const capture = await callController(
        listRecruiterApplicantsFiltered,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { query: { limit: "10", offset: "20" } },
        ),
      );

      const body = capture.body as {
        total: number;
        limit: number;
        offset: number;
        applicants: Array<{ applicant: Record<string, unknown> }>;
      };

      assert.equal(body.total, 37);
      assert.equal(body.limit, 10);
      assert.equal(body.offset, 20);
      // Data pribadi berlebih tidak ikut dikirim.
      assert.deepEqual(body.applicants[0].applicant, { username: "budi" });
    } finally {
      restore();
    }
  });
});

describe("PATCH /api/recruiter/applicants/:id/status", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      updateApplicationStatus,
      makeRecruiterReq(undefined, {
        body: { status: "rejected" },
        params: { id: "9" },
      }),
    );

    assert.equal(capture.status, 401);
  });

  it("menolak status yang tidak diizinkan", async () => {
    const { captured, restore } = stubDbQuery(async () => [[], []]);

    try {
      for (const status of ["hired", "interview", "accepted", "pending", ""]) {
        const capture = await callController(
          updateApplicationStatus,
          makeRecruiterReq(
            { id: 42, role: "recruiter" },
            { body: { status }, params: { id: "9" } },
          ),
        );

        assert.equal(capture.status, 400, `status "${status}" seharusnya ditolak`);
      }

      // Tidak ada UPDATE yang dijalankan untuk input tidak valid.
      assert.equal(captured.length, 0);
    } finally {
      restore();
    }
  });

  it("menerima kedua status yang ada di ENUM database", async () => {
    for (const status of ["submitted", "rejected"]) {
      const { captured, restore } = stubDbQuery(async (sql) => {
        if (/^\s*UPDATE/i.test(sql)) return [{ affectedRows: 1 }, []];
        return [[{ ...applicantRow, status }], []];
      });

      try {
        const capture = await callController(
          updateApplicationStatus,
          makeRecruiterReq(
            { id: 42, role: "recruiter" },
            { body: { status }, params: { id: "9" } },
          ),
        );

        assert.equal(capture.status, 200, `status "${status}" seharusnya diterima`);
        const updateQuery = captured.find((query) => /^\s*UPDATE/i.test(query.sql));
        assert.ok(updateQuery);
        assert.deepEqual(updateQuery.params, [status, 9, 42]);
      } finally {
        restore();
      }
    }
  });

  it("konflik lamaran aktif ganda dijawab 409, bukan 500", async () => {
    const { restore } = stubDbQuery(async (sql) => {
      if (/^\s*UPDATE/i.test(sql)) {
        const error = new Error("Duplicate entry") as Error & { code?: string };
        error.code = "ER_DUP_ENTRY";
        throw error;
      }
      return [[], []];
    });

    try {
      const capture = await callController(
        updateApplicationStatus,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { body: { status: "submitted" }, params: { id: "9" } },
        ),
      );

      assert.equal(capture.status, 409);
      assert.equal(capture.nextError, undefined);
      assert.match(
        String((capture.body as { message?: string }).message),
        /lamaran aktif/i,
      );
    } finally {
      restore();
    }
  });

  it("menolak ID lamaran yang bukan angka", async () => {
    const { restore } = stubDbQuery(async () => [[], []]);

    try {
      const capture = await callController(
        updateApplicationStatus,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { body: { status: "rejected" }, params: { id: "abc" } },
        ),
      );

      assert.equal(capture.status, 400);
    } finally {
      restore();
    }
  });

  it("memverifikasi kepemilikan di dalam UPDATE lewat JOIN jobs", async () => {
    const { captured, restore } = stubDbQuery(async (sql) => {
      if (/^\s*UPDATE/i.test(sql)) return [{ affectedRows: 1 }, []];
      return [[{ ...applicantRow, status: "rejected" }], []];
    });

    try {
      const capture = await callController(
        updateApplicationStatus,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { body: { status: "rejected" }, params: { id: "9" } },
        ),
      );

      assert.equal(capture.status, 200);

      const updateQuery = captured.find((query) => /^\s*UPDATE/i.test(query.sql));
      assert.ok(updateQuery, "harus ada UPDATE");
      // Syarat kepemilikan ikut di dalam UPDATE, bukan hanya di SELECT.
      assert.match(updateQuery.sql, /JOIN jobs j/);
      assert.match(updateQuery.sql, /j\.recruiter_id = \?/);
      assert.deepEqual(updateQuery.params, ["rejected", 9, 42]);
    } finally {
      restore();
    }
  });

  it("lamaran milik recruiter lain dijawab 404, bukan 403", async () => {
    // Recruiter 42 mencoba mengubah lamaran milik lowongan recruiter 99:
    // UPDATE tidak mengenai baris mana pun dan SELECT ulang kosong.
    const { restore } = stubDbQuery(async (sql) => {
      if (/^\s*UPDATE/i.test(sql)) return [{ affectedRows: 0 }, []];
      return [[], []];
    });

    try {
      const capture = await callController(
        updateApplicationStatus,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { body: { status: "rejected" }, params: { id: "9" } },
        ),
      );

      assert.equal(capture.status, 404);
      assert.match(
        String((capture.body as { message?: string }).message),
        /tidak ditemukan/i,
      );
    } finally {
      restore();
    }
  });

  it("kegagalan database diteruskan ke error handler", async () => {
    const { restore } = stubDbQuery(async () => {
      throw new Error("database unavailable");
    });

    try {
      const capture = await callController(
        updateApplicationStatus,
        makeRecruiterReq(
          { id: 42, role: "recruiter" },
          { body: { status: "rejected" }, params: { id: "9" } },
        ),
      );

      assert.equal(capture.status, undefined);
      assert.equal(capture.nextError, true);
    } finally {
      restore();
    }
  });
});
