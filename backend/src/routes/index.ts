import { Router } from 'express';

import { attendanceRouter } from './attendance.routes';
import { authRouter } from './auth.routes';
import { clubInvitesRouter } from './club-invites.routes';
import { clubsRouter } from './clubs.routes';
import { healthRouter } from './health.routes';
import { lineupsRouter } from './lineups.routes';
import { notificationsRouter } from './notifications.routes';
import { playersRouter } from './players.routes';
import { realtimeRouter } from './realtime.routes';
import { streamsRouter } from './streams.routes';
import { clubInfoRouter } from './club-info.routes';
import { vicePermissionsRouter } from './vice-permissions.routes';

export const apiRouter = Router();

apiRouter.use('/health', healthRouter);
apiRouter.use('/realtime', realtimeRouter);
apiRouter.use('/auth', authRouter);
apiRouter.use('/clubs', clubsRouter);
apiRouter.use('/club-invites', clubInvitesRouter);
apiRouter.use('/notifications', notificationsRouter);
apiRouter.use('/players', playersRouter);
apiRouter.use('/lineups', lineupsRouter);
apiRouter.use('/streams', streamsRouter);
apiRouter.use('/attendance', attendanceRouter);
apiRouter.use('/club-info', clubInfoRouter);
apiRouter.use('/team-info', clubInfoRouter);
apiRouter.use('/vice-permissions', vicePermissionsRouter);
