import type { NextFunction, Request, Response } from "express";
import { db } from "../config/database.js";


export interface HandlerCapture {
  status?: number;
  body?: unknown;
  headers?: Record<string, string>;
  buffer?: Buffer;
  nextError?: unknown;
}

export function makeReq(
  user: { id: number; role: string } | undefined,
  body?: unknown,
): Request {
  return { user, body } as unknown as Request;
}

function makeRes(capture: HandlerCapture): Response {
  return {
    status(code: number) {
      capture.status = code;
      return this;
    },
    json(body: unknown) {
      capture.body = body;
      return this;
    },
    setHeader(name: string, value: number | string | readonly string[]) {
      capture.headers ??= {};
      capture.headers[name.toLowerCase()] = Array.isArray(value)
        ? value.join(", ")
        : String(value);
      return this;
    },
    send(body: unknown) {
      if (Buffer.isBuffer(body)) {
        capture.buffer = body;
      } else {
        capture.body = body;
      }
      return this;
    },
  } as unknown as Response;
}

function makeNext(capture: HandlerCapture): NextFunction {
  return (() => {
    capture.nextError = true;
  }) as unknown as NextFunction;
}

export function callMiddleware(
  handler: (req: Request, res: Response, next: NextFunction) => void,
  req: Request,
): HandlerCapture {
  const capture: HandlerCapture = {};
  handler(req, makeRes(capture), makeNext(capture));
  return capture;
}

export async function callController(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
  req: Request,
): Promise<HandlerCapture> {
  const capture: HandlerCapture = {};

  return new Promise((resolve, reject) => {
    handler(req, makeRes(capture), makeNext(capture)).then(
      () => resolve(capture),
      reject,
    );
  });
}

export interface PoolQueryStub {
  /** Daftar query yang tertangkap: sql dan params. */
  calls: Array<{ sql: string; params: unknown[] | undefined }>;
  restore: () => void;
}

/**
 * Mengganti pool.query (properti db.query yang dipakai controller) dengan fungsi
 * jawab SQL, lalu mengembalikan fungsi restore. Semua query yang dipanggil saat
 * stub aktif terekam di `calls`.
 */
export function stubPoolQuery(
  respond: (
    sql: string,
    params: unknown[] | undefined,
  ) => unknown,
): PoolQueryStub {
  const pool = db as unknown as {
    query: (sql: string, params?: unknown[]) => Promise<unknown>;
  };
  const originalQuery = pool.query;
  const calls: Array<{ sql: string; params: unknown[] | undefined }> = [];

  pool.query = (sql: string, params?: unknown[]) => {
    calls.push({ sql, params });
    return Promise.resolve(respond(sql, params));
  };

  return {
    calls,
    restore: () => {
      pool.query = originalQuery;
    },
  };
}
