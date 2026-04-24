import { Router } from 'express';

import { sendCreated, sendNoContent, sendOk } from '../lib/http';
import { publishRealtimeChange } from '../lib/realtime-publisher';
import { supabaseDb } from '../lib/supabase';
import { asyncHandler } from '../middleware/async-handler';
import { requireAuth } from '../middleware/auth';
import { ClubsService } from '../services/clubs.service';
import {
  createClubSchema,
  joinClubSchema,
  listClubsQuerySchema,
  transferCaptainSchema,
  updateLogoSchema,
} from '../validation/clubs.validation';

const clubsService = new ClubsService(supabaseDb);

export const clubsRouter = Router();

clubsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { q, page, limit } = listClubsQuerySchema.parse(req.query);
    const result = await clubsService.listClubs({
      search: q,
      page,
      limit,
    });
    sendOk(res, result);
  }),
);

clubsRouter.get(
  '/current',
  requireAuth,
  asyncHandler(async (req, res) => {
    const club = await clubsService.getCurrentClub(req.principal!);
    sendOk(res, { club });
  }),
);

clubsRouter.get(
  '/current/membership',
  requireAuth,
  asyncHandler(async (req, res) => {
    const membership = await clubsService.getCurrentMembership(req.principal!);
    sendOk(res, { membership });
  }),
);

clubsRouter.get(
  '/current/pending-join-request',
  requireAuth,
  asyncHandler(async (req, res) => {
    const joinRequest = await clubsService.getCurrentPendingJoinRequest(req.principal!.authUser.id);
    sendOk(res, { joinRequest });
  }),
);

clubsRouter.get(
  '/current/pending-leave-request',
  requireAuth,
  asyncHandler(async (req, res) => {
    const membership = req.principal!.membership;
    if (!membership) {
      sendOk(res, { leaveRequest: null });
      return;
    }

    const leaveRequest = await clubsService.getCurrentPendingLeaveRequest(membership.id);
    sendOk(res, { leaveRequest });
  }),
);

clubsRouter.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const result = await clubsService.createClub(
      createClubSchema.parse(req.body),
      req.principal!,
    );
    publishRealtimeChange(['clubs', 'players', 'clubInfo'], 'club_created');
    sendCreated(res, result);
  }),
);

clubsRouter.put(
  '/current/logo',
  requireAuth,
  asyncHandler(async (req, res) => {
    const club = await clubsService.updateCurrentClubLogo(
      updateLogoSchema.parse(req.body),
      req.principal!,
    );
    publishRealtimeChange(['clubs', 'clubInfo'], 'club_logo_updated');
    sendOk(res, { club });
  }),
);

clubsRouter.delete(
  '/current',
  requireAuth,
  asyncHandler(async (req, res) => {
    await clubsService.deleteCurrentClub(req.principal!);
    publishRealtimeChange(['clubs', 'players', 'lineups', 'streams', 'attendance'], 'club_deleted');
    sendNoContent(res);
  }),
);

clubsRouter.post(
  '/join-requests',
  requireAuth,
  asyncHandler(async (req, res) => {
    const joinRequest = await clubsService.requestJoinClub(
      joinClubSchema.parse(req.body),
      req.principal!,
    );
    publishRealtimeChange(['clubs'], 'join_request_created');
    sendCreated(res, { joinRequest });
  }),
);

clubsRouter.delete(
  '/join-requests/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    await clubsService.cancelJoinRequest(req.params.id, req.principal!);
    publishRealtimeChange(['clubs'], 'join_request_cancelled');
    sendNoContent(res);
  }),
);

clubsRouter.get(
  '/join-requests/pending',
  requireAuth,
  asyncHandler(async (req, res) => {
    const joinRequests = await clubsService.listPendingJoinRequests(req.principal!);
    sendOk(res, { joinRequests });
  }),
);

clubsRouter.post(
  '/join-requests/:id/approve',
  requireAuth,
  asyncHandler(async (req, res) => {
    const membership = await clubsService.approveJoinRequest(req.params.id, req.principal!);
    publishRealtimeChange(['clubs', 'players'], 'join_request_approved');
    sendOk(res, { membership });
  }),
);

clubsRouter.post(
  '/join-requests/:id/reject',
  requireAuth,
  asyncHandler(async (req, res) => {
    await clubsService.rejectJoinRequest(req.params.id, req.principal!);
    publishRealtimeChange(['clubs'], 'join_request_rejected');
    sendNoContent(res);
  }),
);

clubsRouter.post(
  '/leave-requests',
  requireAuth,
  asyncHandler(async (req, res) => {
    const leaveRequest = await clubsService.requestLeaveClub(req.principal!);
    publishRealtimeChange(['clubs'], 'leave_request_created');
    sendCreated(res, { leaveRequest });
  }),
);

clubsRouter.delete(
  '/leave-requests/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    await clubsService.cancelLeaveRequest(req.params.id, req.principal!);
    publishRealtimeChange(['clubs'], 'leave_request_cancelled');
    sendNoContent(res);
  }),
);

clubsRouter.get(
  '/leave-requests/pending',
  requireAuth,
  asyncHandler(async (req, res) => {
    const leaveRequests = await clubsService.listPendingLeaveRequests(req.principal!);
    sendOk(res, { leaveRequests });
  }),
);

clubsRouter.post(
  '/leave-requests/:id/approve',
  requireAuth,
  asyncHandler(async (req, res) => {
    await clubsService.approveLeaveRequest(req.params.id, req.principal!);
    publishRealtimeChange(['clubs', 'players'], 'leave_request_approved');
    sendNoContent(res);
  }),
);

clubsRouter.post(
  '/leave-requests/:id/reject',
  requireAuth,
  asyncHandler(async (req, res) => {
    await clubsService.rejectLeaveRequest(req.params.id, req.principal!);
    publishRealtimeChange(['clubs'], 'leave_request_rejected');
    sendNoContent(res);
  }),
);

clubsRouter.post(
  '/transfer-captain',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { target_membership_id: targetMembershipId } = transferCaptainSchema.parse(req.body);
    await clubsService.transferCaptain(targetMembershipId, req.principal!);
    publishRealtimeChange(['clubs', 'players'], 'captain_transferred');
    sendNoContent(res);
  }),
);
