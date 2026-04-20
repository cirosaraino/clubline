import { Router } from 'express';

import { asyncHandler } from '../middleware/async-handler';
import { sendOk } from '../lib/http';

export const healthRouter = Router();

healthRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    sendOk(res, {
      status: 'ok',
      service: 'clubline-backend',
      timestamp: new Date().toISOString(),
    });
  }),
);
