import type { PoolConnection, RowDataPacket } from "mysql2/promise";
import type { Pool } from "mysql2/promise";

export type NotificationType =
  | "application_received"
  | "application_rejected";

type Queryable = Pool | PoolConnection;

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

  if (!job || typeof job.recruiter_id !== "number") return;

  await createNotification(db, {
    recipientId: job.recruiter_id,
    type: "application_received",
    message: `${params.applicantUsername} melamar lowongan "${job.title ?? ""}".`,
    jobId: params.jobId,
    applicationId: params.applicationId,
  });
}

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
