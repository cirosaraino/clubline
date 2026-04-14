import { Router } from 'express';

import { attendanceRouter } from './attendance.routes';
import { authRouter } from './auth.routes';
import { healthRouter } from './health.routes';
import { lineupsRouter } from './lineups.routes';
import { playersRouter } from './players.routes';
import { realtimeRouter } from './realtime.routes';
import { streamsRouter } from './streams.routes';
import { teamInfoRouter } from './team-info.routes';
import { vicePermissionsRouter } from './vice-permissions.routes';

export const apiRouter = Router();

apiRouter.use('/health', healthRouter);
apiRouter.use('/realtime', realtimeRouter);
apiRouter.use('/auth', authRouter);
apiRouter.use('/players', playersRouter);
apiRouter.use('/lineups', lineupsRouter);
apiRouter.use('/streams', streamsRouter);
apiRouter.use('/attendance', attendanceRouter);
apiRouter.use('/team-info', teamInfoRouter);
apiRouter.use('/vice-permissions', vicePermissionsRouter);
