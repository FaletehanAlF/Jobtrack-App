import type { NextFunction, Request, Response } from "express";

// Helper pengujian: meniru cukup bagian dari Request/Response Express untuk
// menjalankan middleware dan controller tanpa menghidupkan server.

export interface HandlerCapture {
  status?: number;
  body?: unknown;
  nextError?: unknown;
}

// req.user dibuat sebagai { id, role } sama seperti isi token JWT.
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
  } as unknown as Response;
}

function makeNext(capture: HandlerCapture): NextFunction {
  return (() => {
    capture.nextError = true;
  }) as unknown as NextFunction;
}

// Untuk middleware sinkron seperti authorizeRoles.
export function callMiddleware(
  handler: (req: Request, res: Response, next: NextFunction) => void,
  req: Request,
): HandlerCapture {
  const capture: HandlerCapture = {};
  handler(req, makeRes(capture), makeNext(capture));
  return capture;
}

// Untuk controller async yang memakai await db.query(...).
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
