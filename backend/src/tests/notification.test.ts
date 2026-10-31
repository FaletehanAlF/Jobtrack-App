import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { db } from "../config/database.js";
import {
  getUnreadNotificationCount,
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "../controllers/notification.controller.js";
import {
  createNotification,
  notifyApplicationReceived,
  notifyStatusChanged,
} from "../services/notification.service.js";
import { callController, makeReq } from "./helpers.js";

// Tes notifikasi tanpa database: query di-stub dan direkam, sehingga yang
// diuji adalah aturan kepemilikan, validasi, dan bentuk query.

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

function makeNotificationReq(
  user: { id: number; role: string } | undefined,
  options: {
    body?: unknown;
    query?: Record<string, string>;
    params?: Record<string, string>;
  } = {},
) {
  const req = makeReq(user, options.body) as unknown as {
    query?: Record<string, string>;
    params?: Record<string, string>;
  };
  req.query = options.query ?? {};
  req.params = options.params ?? {};
  return req as Parameters<typeof callController>[1];
}

const notificationRow = {
  id: 5,
  type: "application_rejected",
  message: 'Lamaranmu untuk "Backend Developer" ditolak.',
  job_id: 3,
  application_id: 9,
  created_at: new Date(2026, 9, 27, 10),
  read_at: null,
};

describe("GET /api/notifications", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      listNotifications,
      makeNotificationReq(undefined),
    );

    assert.equal(capture.status, 401);
  });

  it("hanya mengambil notifikasi milik penerima dari token", async () => {
    const { captured, restore } = stubDbQuery(async (sql) => {
      if (/COUNT\(\*\) AS total/.test(sql)) return [[{ total: "1" }], []];
      if (/COUNT\(\*\) AS unread/.test(sql)) return [[{ unread: "1" }], []];
      return [[notificationRow], []];
    });

    try {
      // Query berisi recipient_id milik orang lain harus diabaikan.
      const capture = await callController(
        listNotifications,
        makeNotificationReq(
          { id: 7, role: "jobseeker" },
          { query: { recipient_id: "999" } },
        ),
      );

      assert.equal(capture.status, 200);

      for (const query of captured) {
        assert.match(query.sql, /recipient_id = \?/);
        assert.equal(query.params[0], 7);
        assert.equal(
          query.params.includes(999),
          false,
          "recipient_id dari query tidak boleh dipakai",
        );
      }
    } finally {
      restore();
    }
  });

  it("mengembalikan daftar, total, dan jumlah belum dibaca", async () => {
    const { restore } = stubDbQuery(async (sql) => {
      if (/COUNT\(\*\) AS total/.test(sql)) return [[{ total: "12" }], []];
      if (/COUNT\(\*\) AS unread/.test(sql)) return [[{ unread: "3" }], []];
      return [[notificationRow], []];
    });

    try {
      const capture = await callController(
        listNotifications,
        makeNotificationReq({ id: 7, role: "jobseeker" }),
      );

      const body = capture.body as {
        notifications: Array<{ is_read: boolean; message: string }>;
        total: number;
        unread: number;
        limit: number;
        offset: number;
      };

      assert.equal(body.total, 12);
      assert.equal(body.unread, 3);
      assert.equal(body.limit, 50);
      assert.equal(body.offset, 0);
      assert.equal(body.notifications[0].is_read, false);
      assert.match(body.notifications[0].message, /ditolak/);
    } finally {
      restore();
    }
  });

  it("menolak limit di atas batas maksimum", async () => {
    const { restore } = stubDbQuery(async () => [[], []]);

    try {
      const capture = await callController(
        listNotifications,
        makeNotificationReq(
          { id: 7, role: "jobseeker" },
          { query: { limit: "5000" } },
        ),
      );

      assert.equal(capture.status, 400);
    } finally {
      restore();
    }
  });

  it("error database diteruskan ke error handler, bukan respons sukses", async () => {
    const { restore } = stubDbQuery(async () => {
      throw new Error("database unavailable");
    });

    try {
      const capture = await callController(
        listNotifications,
        makeNotificationReq({ id: 7, role: "jobseeker" }),
      );

      assert.equal(capture.status, undefined);
      assert.equal(capture.nextError, true);
    } finally {
      restore();
    }
  });
});

describe("GET /api/notifications/unread-count", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      getUnreadNotificationCount,
      makeNotificationReq(undefined),
    );

    assert.equal(capture.status, 401);
  });

  it("menghitung belum dibaca hanya untuk penerima dari token", async () => {
    const { captured, restore } = stubDbQuery(async () => [
      [{ unread: "4" }],
      [],
    ]);

    try {
      const capture = await callController(
        getUnreadNotificationCount,
        makeNotificationReq({ id: 7, role: "jobseeker" }),
      );

      assert.equal(capture.status, 200);
      assert.deepEqual(capture.body, { unread: 4 });
      assert.match(captured[0].sql, /read_at IS NULL/);
      assert.deepEqual(captured[0].params, [7]);
    } finally {
      restore();
    }
  });
});

describe("PATCH /api/notifications/:id/read", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      markNotificationRead,
      makeNotificationReq(undefined, { params: { id: "5" } }),
    );

    assert.equal(capture.status, 401);
  });

  it("menyertakan recipient_id di dalam UPDATE sehingga notifikasi orang lain tidak terbaca", async () => {
    const { captured, restore } = stubDbQuery(async (sql) => {
      if (/^\s*UPDATE/i.test(sql)) return [{ affectedRows: 1 }, []];
      return [[{ ...notificationRow, read_at: new Date() }], []];
    });

    try {
      const capture = await callController(
        markNotificationRead,
        makeNotificationReq({ id: 7, role: "jobseeker" }, { params: { id: "5" } }),
      );

      assert.equal(capture.status, 200);

      const update = captured.find((query) => /^\s*UPDATE/i.test(query.sql));
      assert.ok(update);
      assert.match(update.sql, /recipient_id = \?/);
      assert.deepEqual(update.params, [5, 7]);
    } finally {
      restore();
    }
  });

  it("notifikasi milik pengguna lain dijawab 404, bukan 403", async () => {
    const { restore } = stubDbQuery(async (sql) => {
      if (/^\s*UPDATE/i.test(sql)) return [{ affectedRows: 0 }, []];
      // SELECT ulang dengan recipient_id pemilik lain tidak menemukan apa pun.
      return [[], []];
    });

    try {
      const capture = await callController(
        markNotificationRead,
        makeNotificationReq(
          { id: 8, role: "jobseeker" },
          { params: { id: "5" } },
        ),
      );

      assert.equal(capture.status, 404);
    } finally {
      restore();
    }
  });

  it("menolak ID notifikasi yang bukan angka", async () => {
    const { restore } = stubDbQuery(async () => [[], []]);

    try {
      const capture = await callController(
        markNotificationRead,
        makeNotificationReq(
          { id: 7, role: "jobseeker" },
          { params: { id: "abc" } },
        ),
      );

      assert.equal(capture.status, 400);
    } finally {
      restore();
    }
  });
});

describe("PATCH /api/notifications/read-all", () => {
  it("menolak request tanpa token dengan 401", async () => {
    const capture = await callController(
      markAllNotificationsRead,
      makeNotificationReq(undefined),
    );

    assert.equal(capture.status, 401);
  });

  it("hanya memperbarui notifikasi milik penerima dari token", async () => {
    const { captured, restore } = stubDbQuery(async () => [
      { affectedRows: 3 },
      [],
    ]);

    try {
      const capture = await callController(
        markAllNotificationsRead,
        makeNotificationReq({ id: 7, role: "recruiter" }),
      );

      assert.equal(capture.status, 200);
      assert.match(captured[0].sql, /recipient_id = \?/);
      assert.match(captured[0].sql, /read_at IS NULL/);
      assert.deepEqual(captured[0].params, [7]);
    } finally {
      restore();
    }
  });
});

describe("Pembuatan notifikasi", () => {
  it("memakai INSERT IGNORE agar kejadian yang sama tidak menghasilkan notifikasi ganda", async () => {
    const { captured, restore } = stubDbQuery(async () => [
      { affectedRows: 1 },
      [],
    ]);

    try {
      await createNotification(db, {
        recipientId: 7,
        type: "application_rejected",
        message: "Lamaranmu ditolak.",
        jobId: 3,
        applicationId: 9,
      });

      assert.match(captured[0].sql, /INSERT IGNORE INTO notifications/);
      assert.deepEqual(captured[0].params, [
        7,
        "application_rejected",
        "Lamaranmu ditolak.",
        3,
        9,
      ]);
    } finally {
      restore();
    }
  });

  it("notifikasi recruiter diarahkan ke pemilik lowongan dari database", async () => {
    const { captured, restore } = stubDbQuery(async (sql) => {
      if (/FROM jobs/.test(sql)) {
        return [[{ recruiter_id: 42, title: "Backend Developer" }], []];
      }
      return [{ affectedRows: 1 }, []];
    });

    try {
      await notifyApplicationReceived(db, {
        jobId: 3,
        applicationId: 9,
        applicantUsername: "budi",
      });

      const insert = captured.find((query) =>
        /INSERT IGNORE INTO notifications/.test(query.sql),
      );
      assert.ok(insert);
      // Penerima berasal dari jobs.recruiter_id, bukan dari parameter klien.
      assert.equal(insert.params[0], 42);
      assert.equal(insert.params[1], "application_received");
      assert.match(String(insert.params[2]), /budi/);
    } finally {
      restore();
    }
  });

  it("lowongan yang sudah terhapus tidak menghasilkan notifikasi", async () => {
    const { captured, restore } = stubDbQuery(async () => [[], []]);

    try {
      await notifyApplicationReceived(db, {
        jobId: 3,
        applicationId: 9,
        applicantUsername: "budi",
      });

      assert.equal(
        captured.some((query) => /INSERT IGNORE/.test(query.sql)),
        false,
      );
    } finally {
      restore();
    }
  });

  it("status selain rejected tidak membuat notifikasi penolakan", async () => {
    const { captured, restore } = stubDbQuery(async () => [
      { affectedRows: 1 },
      [],
    ]);

    try {
      await notifyStatusChanged(db, {
        applicantId: 7,
        applicationId: 9,
        jobId: 3,
        jobTitle: "Backend Developer",
        status: "submitted",
      });

      assert.equal(captured.length, 0);
    } finally {
      restore();
    }
  });

  it("penolakan mengirim notifikasi ke pelamar pemilik lamaran", async () => {
    const { captured, restore } = stubDbQuery(async () => [
      { affectedRows: 1 },
      [],
    ]);

    try {
      await notifyStatusChanged(db, {
        applicantId: 7,
        applicationId: 9,
        jobId: 3,
        jobTitle: "Backend Developer",
        status: "rejected",
      });

      const insert = captured.find((query) =>
        /INSERT IGNORE INTO notifications/.test(query.sql),
      );
      assert.ok(insert);
      assert.equal(insert.params[0], 7);
      assert.equal(insert.params[1], "application_rejected");
    } finally {
      restore();
    }
  });

  it("kegagalan insert notifikasi dilempar agar transaksi bisa dibatalkan", async () => {
    const { restore } = stubDbQuery(async () => {
      throw new Error("insert failed");
    });

    try {
      await assert.rejects(
        createNotification(db, {
          recipientId: 7,
          type: "application_received",
          message: "x",
          jobId: 3,
          applicationId: 9,
        }),
        /insert failed/,
      );
    } finally {
      restore();
    }
  });
});
