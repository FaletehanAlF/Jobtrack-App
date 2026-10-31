import type { PoolConnection, RowDataPacket } from "mysql2/promise";
import type { Pool } from "mysql2/promise";

// Jenis notifikasi yang dikenal. Harus sama dengan ENUM kolom
// notifications.type pada migration table-notifications.sql.
export type NotificationType =
  | "application_received"
  | "application_rejected";

// Klien query. Pool (db) dan PoolConnection sama-sama punya query(), jadi
// fungsi di bawah bisa dipanggil di dalam maupun di luar transaksi.
type Queryable = Pool | PoolConnection;

/**
 * Membuat satu notifikasi bila belum ada untuk kejadian yang sama.
 *
 * `INSERT IGNORE` dipakai alih-alih `INSERT ... ON DUPLICATE KEY UPDATE`
 * supaya baris yang sudah ada tidak tersentuh sama sekali — termasuk
 * read_at, sehingga notifikasi yang sudah dibaca sebelumnya tidak muncul
 * lagi sebagai belum dibaca hanya karena kejadiannya terulang.
 *
 * Unik-nya dijaga `uq_notification_event (recipient_id, type, application_id)`
 * di database, jadi dua request bersamaan tidak bisa menghasilkan dua baris.
 *
 * Dipanggil HANYA setelah perubahan data berhasil, dan sedapat mungkin di
 * dalam transaksi yang sama, sehingga tidak ada notifikasi untuk perubahan
 * yang gagal tersimpan.
 */
export async function createNotification(
  db: Queryable,
  notification: {
    recipientId: number;
    type: NotificationType;
    message: string;
    jobId: number | null;
    applicationId: number | null;
  },
): Promise<void> {
  await db.query(
    `INSERT IGNORE INTO notifications
       (recipient_id, type, message, job_id, application_id)
     VALUES (?, ?, ?, ?, ?)`,
    [
      notification.recipientId,
      notification.type,
      notification.message,
      notification.jobId,
      notification.applicationId,
    ],
  );
}

/**
 * Membuat notifikasi ke recruiter pemilik lowongan saat ada lamaran baru.
 *
 * Pemilik lowongan dibaca dari database berdasarkan `job_id`, bukan dari
 * request, sehingga notifikasi tidak bisa diarahkan ke recruiter lain.
 */
export async function notifyApplicationReceived(
  db: Queryable,
  params: {
    jobId: number;
    applicationId: number;
    applicantUsername: string;
  },
): Promise<void> {
  const [rows] = await db.query<RowDataPacket[]>(
    "SELECT recruiter_id, title FROM jobs WHERE id = ? LIMIT 1",
    [params.jobId],
  );

  const job = rows[0] as { recruiter_id?: number; title?: string } | undefined;

  // Lowongan bisa terhapus di antara INSERT lamaran dan pemanggilan ini.
  // Notifikasi saja yang dilewati; lamaran yang sudah tersimpan tetap sah.
  if (!job || typeof job.recruiter_id !== "number") return;

  await createNotification(db, {
    recipientId: job.recruiter_id,
    type: "application_received",
    message: `${params.applicantUsername} melamar lowongan "${job.title ?? ""}".`,
    jobId: params.jobId,
    applicationId: params.applicationId,
  });
}

/**
 * Membuat notifikasi ke pelamar saat lamarannya berubah status.
 *
 * Hanya dipanggil ketika status benar-benar berubah, sehingga penolakan
 * berulang atas lamaran yang sama tidak menghasilkan notifikasi baru.
 */
export async function notifyStatusChanged(
  db: Queryable,
  params: {
    applicantId: number;
    applicationId: number;
    jobId: number;
    jobTitle: string;
    status: string;
  },
): Promise<void> {
  if (params.status === "rejected") {
    await createNotification(db, {
      recipientId: params.applicantId,
      type: "application_rejected",
      message: `Lamaranmu untuk "${params.jobTitle}" ditolak.`,
      jobId: params.jobId,
      applicationId: params.applicationId,
    });
  }
}
