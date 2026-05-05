import type { AddressInfo } from 'node:net';
import type { RequestHandler, Router } from 'express';
import express from 'express';

import type { RequestPrincipal } from '../../domain/types';
import { errorHandler, notFoundHandler } from '../../middleware/error-handler';

export function authAs(principal: RequestPrincipal): RequestHandler {
  return (req, _res, next) => {
    req.principal = principal;
    next();
  };
}

export async function withTestServer(
  router: Router,
  run: (baseUrl: string) => Promise<void>,
): Promise<void> {
  const app = express();
  app.use(express.json());
  app.use('/api', router);
  app.use(notFoundHandler);
  app.use(errorHandler);

  const server = await new Promise<import('node:http').Server>((resolve) => {
    const nextServer = app.listen(0, () => resolve(nextServer));
  });

  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}/api`;

  try {
    await run(baseUrl);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }

        resolve();
      });
    });
  }
}
