import cors from 'cors';
import express from 'express';
import helmet from 'helmet';

import { corsOrigins, env } from './config/env';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { apiRouter } from './routes';

function isAllowedOrigin(origin: string | undefined): boolean {
  if (!origin || origin == 'null') {
    return true;
  }

  if (corsOrigins.includes(origin)) {
    return true;
  }

  if (env.NODE_ENV != 'development') {
    return false;
  }

  return origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:');
}

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        if (isAllowedOrigin(origin)) {
          callback(null, true);
          return;
        }

        callback(new Error(`Origin non consentita: ${origin}`));
      },
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '1mb' }));

  app.use('/api', apiRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
