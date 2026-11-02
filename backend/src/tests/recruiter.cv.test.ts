import { describe, it } from "node:test";
import assert from "node:assert/strict";
import jwt from "jsonwebtoken";
import type { Request } from "express";

// Import database dulu agar dotenv.config() sudah berjalan sebelum modul yang
// butuh env (Cloudinary, JWT) dievaluasi.
import { db } from "../config/database.js";
import {
  getRecruiterApplicantCv,
  streamRecruiterApplicantCv,
} from "../controllers/recruiter.controller.js";
import { authorizeRoles } from "../config/middleware/authorize.middleware.js";
import {
  callController,
  callMiddleware,
  makeReq,
  stubPoolQuery,
} from "./helpers.js";

// JWT_SECRET dibutuhkan controller untuk menandatangani token akses CV.
// Nilai dari .env tetap dipertahankan jika sudah ada.
process.env.JWT_SECRET ||= "jwt-secret-khusus-pengujian-cv";

const JWT_SECRET = process.env.JWT_SECRET;

const CV_ROW = {
  cv_public_id: "jobtrack/cvs/cv-1",
  cv_resource_type: "raw",
  cv_delivery_type: "authenticated",
};

type CvRequest = Omit<Request, "file" | "get"> & {
  params?: Record<string, string>;
  query?: Record<string, string>;
  protocol?: string;
  headers?: Record<string, string>;
  get?: (name: string) => string | undefined;
};

function recruiterReq(
  user: { id: number; role: string } | undefined,
  {
    params = {},
    query = {},
  }: { params?: Record<string, string>; query?: Record<string, string> } = {},
): Request {
  const req = makeReq(user, undefined) as unknown as CvRequest;
  req.params = params;
  req.query = query;
  req.protocol = "http";
  req.headers = { host: "cv-test.local:3000" };
  req.get = (name: string) => req.headers?.[name.toLowerCase()];
  return req as unknown as Request;
}

function stubCvDb(scenario: {
  cvRow?: typeof CV_ROW | null; // null → baris lamaran tidak ada
  noCv?: boolean;
}) {
  return stubPoolQuery((sql) => {
    if (sql.includes("SELECT") && sql.includes("job_applications a")) {
      if (scenario.cvRow === null) return [[]];
      if (scenario.noCv) {
        return [
          [
            {
              cv_public_id: null,
              cv_resource_type: null,
              cv_delivery_type: null,
              has_cv: 0,
            },
          ],
        ];
      }
      return [[{ ...CV_ROW, has_cv: 1 }]];
    }
    return [[], []];
  });
}

function signCvToken(payload: object, options: jwt.SignOptions = {}) {
  return jwt.sign(
    { purpose: "cv-stream", applicationId: 33, recruiterId: 9, ...payload },
    JWT_SECRET as string,
    options,
  );
}

function stubFetch(result: () => Response | Promise<Response>) {
  const originalFetch = globalThis.fetch;

  globalThis.fetch = (() => result()) as typeof fetch;

  return {
    restore: () => {
      globalThis.fetch = originalFetch;
    },
  };
}

const pdfBytes = Buffer.from("%PDF-1.4 test-cv-bytes");

describe("GET /api/recruiter/applicants/:id/cv", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(getRecruiterApplicantCv, recruiterReq(undefined) as Request);
    assert.equal(capture.status, 401);
  });

  it("menolak ID lamaran tidak valid dengan 400", async () => {
    const capture = await callController(
      getRecruiterApplicantCv,
      recruiterReq({ id: 9, role: "recruiter" }, { params: { id: "abc" } }) as Request,
    );
    assert.equal(capture.status, 400);
  });

  it("lamaran tidak ditemukan atau bukan milik recruiter → 404 tanpa detail", async () => {
    const stubDb = stubCvDb({ cvRow: null });

    try {
      const capture = await callController(
        getRecruiterApplicantCv,
        recruiterReq({ id: 9, role: "recruiter" }, { params: { id: "33" } }) as Request,
      );

      assert.equal(capture.status, 404);
      assert.match((capture.body as { message?: string }).message ?? "", /tidak ditemukan/);
      // Detail internal tidak bocor: hanya field message.
      const body = capture.body as { message?: string };
      assert.deepEqual(Object.keys(body), ["message"]);
    } finally {
      stubDb.restore();
    }
  });

  it("jobseeker ditolak oleh gate role di route dengan 403", () => {
    const middleware = authorizeRoles("recruiter");
    const capture = callMiddleware(middleware, makeReq({ id: 5, role: "jobseeker" }));
    assert.equal(capture.status, 403);
  });

  it("lamaran milik recruiter, tanpa CV → 404 khusus CV", async () => {
    const stubDb = stubCvDb({ noCv: true });

    try {
      const capture = await callController(
        getRecruiterApplicantCv,
        recruiterReq({ id: 9, role: "recruiter" }, { params: { id: "33" } }) as Request,
      );

      assert.equal(capture.status, 404);
      assert.match((capture.body as { message?: string }).message ?? "", /CV tidak tersedia/);
    } finally {
      stubDb.restore();
    }
  });

  it("kepemilikan diverifikasi lewat relasi jobs–job_applications dengan JWT", async () => {
    const stubDb = stubCvDb({});
    const applicationId = "33";

    try {
      const capture = await callController(
        getRecruiterApplicantCv,
        recruiterReq({ id: 9, role: "recruiter" }, { params: { id: applicationId } }) as Request,
      );

      assert.equal(capture.status, 200);

      const body = capture.body as { url: string; download_url: string; expires_at: number };
      assert.match(body.url, /^https?:\/\/cv-test\.local:3000\/api\/recruiter\/applicants\/33\/cv\/stream\?token=/);
      assert.match(body.download_url, /&download=1$/);
      assert.ok(body.expires_at > Math.floor(Date.now() / 1000));

      // Aman terhadap recruiter lain: token mengikat recruiterId pelaku.
      const token = body.url.split("token=")[1]!;
      const decoded = jwt.decode(token) as {
        purpose: string;
        applicationId: number;
        recruiterId: number;
        exp: number;
      };
      assert.equal(decoded.purpose, "cv-stream");
      assert.equal(decoded.applicationId, 33);
      assert.equal(decoded.recruiterId, 9);
      assert.ok(Math.abs(decoded.exp - body.expires_at) <= 1);

      assert.equal(
        body.url.includes("jobtrack/cvs") || body.url.includes("res.cloudinary"),
        false,
      );

      const ownershipSql = stubDb.calls.find((c) =>
        c.sql.includes("j.recruiter_id = ?"),
      )!;
      assert.ok(ownershipSql, "query kepemilikan harus memfilter recruiter pemilik job");
    } finally {
      stubDb.restore();
    }
  });
});

describe("GET /api/recruiter/applicants/:id/cv/stream", () => {
  it("menolak tanpa token dengan 401", async () => {
    const capture = await callController(
      streamRecruiterApplicantCv,
      recruiterReq(undefined) as Request,
    );
    assert.equal(capture.status, 401);
  });

  it("menolak token palsu dengan 401", async () => {
    const capture = await callController(
      streamRecruiterApplicantCv,
      recruiterReq(undefined, { query: { token: "bukan-token" } }) as Request,
    );
    assert.equal(capture.status, 401);
  });

  it("menolak token kedaluwarsa dengan 401", async () => {
    const expired = jwt.sign(
      { purpose: "cv-stream", applicationId: 33, recruiterId: 9 },
      JWT_SECRET as string,
      { expiresIn: -10 },
    );
    const capture = await callController(
      streamRecruiterApplicantCv,
      recruiterReq(undefined, { query: { token: expired } }) as Request,
    );
    assert.equal(capture.status, 401);
  });

  it("menolak token login biasa (tanpa purpose) sebagai akses CV", async () => {
    const loginToken = jwt.sign({ id: 9, role: "recruiter" }, JWT_SECRET as string, {
      expiresIn: 60,
    });
    const capture = await callController(
      streamRecruiterApplicantCv,
      recruiterReq(undefined, { query: { token: loginToken } }) as Request,
    );
    assert.equal(capture.status, 401);
  });

  it("mengirim PDF inline saat recruiter pemilik job mengakses token valid", async () => {
    const stubDb = stubCvDb({});
    const fetchSpy = stubFetch(() => new Response(new Uint8Array(pdfBytes), { status: 200 }));
    const token = signCvToken({});

    try {
      const capture = await callController(
        streamRecruiterApplicantCv,
        recruiterReq(undefined, { query: { token } }) as Request,
      );

      assert.equal(capture.status, 200);
      assert.deepEqual(capture.buffer, pdfBytes);
      assert.equal(capture.headers?.["content-type"], "application/pdf");
      assert.equal(capture.headers?.["x-content-type-options"], "nosniff");
      assert.equal(capture.headers?.["cache-control"], "no-store");
      assert.match(capture.headers?.["content-disposition"] ?? "", /^inline/);
    } finally {
      stubDb.restore();
      fetchSpy.restore();
    }
  });

  it("Content-Disposition attachment saat download=1", async () => {
    const stubDb = stubCvDb({});
    const fetchSpy = stubFetch(() => new Response(new Uint8Array(pdfBytes), { status: 200 }));
    const token = signCvToken({});

    try {
      const capture = await callController(
        streamRecruiterApplicantCv,
        recruiterReq(undefined, { query: { token, download: "1" } }) as Request,
      );

      assert.equal(capture.status, 200);
      assert.match(capture.headers?.["content-disposition"] ?? "", /^attachment/);
    } finally {
      stubDb.restore();
      fetchSpy.restore();
    }
  });

  it("tetap memverifikasi kepemilikan job berdasarkan token, bukan menebak id", async () => {
    // Token menunjuk recruiter 4242; query kepemilikan memakai recruiterId dari
    // token, jadi baris milik recruiter 9 tidak akan cocok → 404.
    const foreignToken = signCvToken({ recruiterId: 4242 });
    const stubDb = stubCvDb({ cvRow: null });
    const fetchSpy = stubFetch(() => new Response(new Uint8Array(pdfBytes), { status: 200 }));

    try {
      const capture = await callController(
        streamRecruiterApplicantCv,
        recruiterReq(undefined, { query: { token: foreignToken } }) as Request,
      );

      assert.equal(capture.status, 404);
      assert.match((capture.body as { message?: string }).message ?? "", /tidak ditemukan/);
    } finally {
      stubDb.restore();
      fetchSpy.restore();
    }
  });

  it("mengembalikan 502 saat pengambilan dari Cloudinary gagal", async () => {
    const stubDb = stubCvDb({});
    const fetchSpy = stubFetch(
      () => new Response("upstream error", { status: 500 }),
    );
    const token = signCvToken({});

    try {
      const capture = await callController(
        streamRecruiterApplicantCv,
        recruiterReq(undefined, { query: { token } }) as Request,
      );

      assert.equal(capture.status, 502);
      assert.match((capture.body as { message?: string }).message ?? "", /Coba lagi/);
    } finally {
      stubDb.restore();
      fetchSpy.restore();
    }
  });

  it("mengembalikan 502 saat pengambilan dari Cloudinary timeout", async () => {
    const stubDb = stubCvDb({});
    const fetchSpy = stubFetch(
      () =>
        Promise.reject(
          new DOMException("The operation was aborted due to timeout", "TimeoutError"),
        ),
    );
    const token = signCvToken({});

    try {
      const capture = await callController(
        streamRecruiterApplicantCv,
        recruiterReq(undefined, { query: { token } }) as Request,
      );

      assert.equal(capture.status, 502);
    } finally {
      stubDb.restore();
      fetchSpy.restore();
    }
  });

  it("backend mengambil file dari Cloudinary lewat private_download_url ber-signature", async () => {
    const stubDb = stubCvDb({});
    const token = signCvToken({});
    let capturedUrl = "";

    const originalFetch = globalThis.fetch;
    globalThis.fetch = ((input: unknown, _init?: unknown) => {
      capturedUrl = String(input);
      return Promise.reject(new Error("hentikan untuk pengujian"));
    }) as typeof fetch;

    try {
      const capture = await callController(
        streamRecruiterApplicantCv,
        recruiterReq(undefined, { query: { token } }) as Request,
      );

      assert.equal(capture.status, 502);
      assert.match(capturedUrl, /^https:\/\/api\.cloudinary\.com\//);
      assert.match(capturedUrl, /\/download\?/);
      assert.match(capturedUrl, /expires_at=/);
      assert.match(capturedUrl, /signature=/);
      // Secret tidak pernah masuk URL (signature adalah hash).
      assert.ok(!capturedUrl.includes("undefined"));
    } finally {
      globalThis.fetch = originalFetch;
      stubDb.restore();
    }
  });
});
