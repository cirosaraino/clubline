import 'dotenv/config';

import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import {
  createClient,
  type PostgrestError,
  type RealtimeChannel,
  type RealtimePostgresChangesPayload,
  type SupabaseClient,
} from '@supabase/supabase-js';

type AuthSession = {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  user: {
    id: string;
    email: string | null;
  };
};

type RegisteredUser = {
  label: string;
  email: string;
  password: string;
  session: AuthSession;
  client: SupabaseClient;
};

type PublicConfigResponse = {
  supabase: {
    url: string;
    anonKey: string;
  };
  realtime: {
    provider: string;
    localFallbackEnabled: boolean;
  };
};

type ClubRecord = {
  id: string | number;
  name: string;
  slug: string;
};

type JoinRequestRecord = {
  id: string | number;
  club_id: string | number;
  requester_user_id: string;
  status: string;
};

type LeaveRequestRecord = {
  id: string | number;
  club_id: string | number;
  membership_id: string | number;
  requested_by_user_id: string;
  status: string;
};

type MembershipRecord = {
  id: string | number;
  club_id: string | number;
  auth_user_id: string;
  role: string;
  status: string;
};

type PlayerRecord = {
  id: string | number;
  club_id: string | number | null;
  membership_id: string | number | null;
  nome: string;
  cognome: string;
  shirt_number: number | null;
  primary_role: string | null;
  id_console: string | null;
};

type LineupRecord = {
  id: string | number;
  club_id: string | number;
  competition_name: string;
  notes: string | null;
};

type CapturedEvent = {
  table: string;
  eventType: string;
  schema: string;
  new: Record<string, unknown>;
  old: Record<string, unknown>;
  payload: RealtimePostgresChangesPayload<Record<string, unknown>>;
};

type CaptureSpec = {
  table: string;
  filter?: string;
  event?: '*' | 'INSERT' | 'UPDATE' | 'DELETE';
};

type CaptureContext = {
  name: string;
  client: SupabaseClient;
  channel: RealtimeChannel;
  events: CapturedEvent[];
  mark(): number;
  waitFor(
    predicate: (event: CapturedEvent) => boolean,
    description: string,
    options?: { timeoutMs?: number; since?: number },
  ): Promise<CapturedEvent>;
  expectNoMatch(
    predicate: (event: CapturedEvent) => boolean,
    description: string,
    options?: { timeoutMs?: number; since?: number },
  ): Promise<void>;
  close(): Promise<void>;
};

type ValidationContext = {
  backendBaseUrl: string;
  publicConfig: PublicConfigResponse;
  serviceClient: SupabaseClient;
  runId: string;
  users: RegisteredUser[];
  clubIds: Array<string | number>;
  subscriptions: CaptureContext[];
};

type RealtimeAuditState = {
  working: boolean;
  issues: string[];
};

const DEFAULT_TIMEOUT_MS = 12000;
const ABSENCE_TIMEOUT_MS = 1800;
const POLL_INTERVAL_MS = 120;

function logStep(message: string): void {
  console.log(`\n[clubline-e2e] ${message}`);
}

function stringifyId(value: string | number | null | undefined): string {
  return value == null ? '' : String(value);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function buildBackendUrl(baseUrl: string, path: string): string {
  const normalizedBase = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${normalizedBase}${normalizedPath}`;
}

function createSupabaseClient(url: string, key: string): SupabaseClient {
  return createClient(url, key, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

async function backendRequest<T>(
  baseUrl: string,
  path: string,
  options: {
    method?: string;
    token?: string;
    body?: unknown;
    expectedStatus?: number;
  } = {},
): Promise<T> {
  const response = await fetch(buildBackendUrl(baseUrl, path), {
    method: options.method ?? 'GET',
    headers: {
      Accept: 'application/json',
      ...(options.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
    },
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
  });

  const raw = await response.text();
  const payload = raw.length > 0 ? JSON.parse(raw) : null;

  if (response.status !== (options.expectedStatus ?? 200)) {
    throw new Error(
      [
        `${options.method ?? 'GET'} ${path} returned ${response.status}, expected ${options.expectedStatus ?? 200}.`,
        raw.length > 0 ? `Payload: ${raw}` : 'No response payload.',
      ].join(' '),
    );
  }

  return payload as T;
}

async function expectBackendError(
  baseUrl: string,
  path: string,
  options: {
    method?: string;
    token?: string;
    body?: unknown;
    expectedStatus: number;
    expectedCode?: string;
  },
): Promise<{ error: { message: string; code?: string } }> {
  const response = await fetch(buildBackendUrl(baseUrl, path), {
    method: options.method ?? 'GET',
    headers: {
      Accept: 'application/json',
      ...(options.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
    },
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
  });

  const raw = await response.text();
  const payload = raw.length > 0 ? JSON.parse(raw) : null;
  assert.equal(
    response.status,
    options.expectedStatus,
    `${options.method ?? 'GET'} ${path} should fail with ${options.expectedStatus}, got ${response.status}. Payload: ${raw}`,
  );
  assert(payload?.error, `Expected structured error payload for ${options.method ?? 'GET'} ${path}`);
  if (options.expectedCode) {
    assert.equal(
      payload.error.code,
      options.expectedCode,
      `Unexpected error code for ${options.method ?? 'GET'} ${path}`,
    );
  }
  return payload as { error: { message: string; code?: string } };
}

function ensureSupabaseSuccess<T>(
  response: { data: T | null; error: PostgrestError | null },
  context: string,
): T {
  if (response.error) {
    throw new Error(`${context} failed: ${response.error.code ?? 'unknown'} ${response.error.message}`);
  }

  return response.data as T;
}

function ensureSupabaseFailure(
  response: { data: unknown; error: PostgrestError | null },
  context: string,
): PostgrestError {
  if (!response.error) {
    throw new Error(`${context} should have failed but succeeded.`);
  }

  return response.error;
}

async function createAuthenticatedUserClient(
  publicConfig: PublicConfigResponse,
  session: AuthSession,
): Promise<SupabaseClient> {
  const client = createSupabaseClient(
    publicConfig.supabase.url,
    publicConfig.supabase.anonKey,
  );

  const setSessionResult = await client.auth.setSession({
    access_token: session.accessToken,
    refresh_token: session.refreshToken,
  });
  if (setSessionResult.error) {
    throw new Error(`Unable to initialize user session for ${session.user.id}: ${setSessionResult.error.message}`);
  }

  await Promise.resolve(client.realtime.setAuth(session.accessToken));
  return client;
}

async function registerUser(
  context: ValidationContext,
  label: string,
): Promise<RegisteredUser> {
  const email = `clubline.${label}.${context.runId}@example.com`;
  const password = `Clubline!${randomUUID().slice(0, 10)}aA1`;

  const result = await backendRequest<{
    verificationRequired: boolean;
    message: string;
    session?: AuthSession;
  }>(context.backendBaseUrl, '/auth/register', {
    method: 'POST',
    expectedStatus: 201,
    body: {
      email,
      password,
    },
  });

  assert.equal(result.verificationRequired, false, `Registration should not require email verification for ${label}`);
  assert(result.session, `Missing auth session after registering ${label}`);

  const client = await createAuthenticatedUserClient(context.publicConfig, result.session);
  const user: RegisteredUser = {
    label,
    email,
    password,
    session: result.session,
    client,
  };
  context.users.push(user);
  return user;
}

async function verifyLogin(
  context: ValidationContext,
  user: RegisteredUser,
): Promise<void> {
  const result = await backendRequest<{ session: AuthSession }>(
    context.backendBaseUrl,
    '/auth/login',
    {
      method: 'POST',
      body: {
        email: user.email,
        password: user.password,
      },
    },
  );
  assert.equal(
    result.session.user.id,
    user.session.user.id,
    `Login returned a different auth user for ${user.label}`,
  );
}

async function subscribeToChanges(
  context: ValidationContext,
  client: SupabaseClient,
  name: string,
  specs: CaptureSpec[],
): Promise<CaptureContext> {
  const events: CapturedEvent[] = [];
  const channel = client.channel(`clubline-e2e-${context.runId}-${name}`);

  for (const spec of specs) {
    channel.on(
      'postgres_changes',
      {
        event: spec.event ?? '*',
        schema: 'public',
        table: spec.table,
        ...(spec.filter ? { filter: spec.filter } : {}),
      },
      (payload) => {
        events.push({
          table: spec.table,
          eventType: payload.eventType,
          schema: payload.schema,
          new: (payload.new ?? {}) as Record<string, unknown>,
          old: (payload.old ?? {}) as Record<string, unknown>,
          payload: payload as RealtimePostgresChangesPayload<Record<string, unknown>>,
        });
      },
    );
  }

  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Timed out subscribing realtime channel ${name}`));
    }, DEFAULT_TIMEOUT_MS);

    channel.subscribe((status, error) => {
      if (status === 'SUBSCRIBED') {
        clearTimeout(timer);
        resolve();
        return;
      }

      if (status === 'TIMED_OUT' || status === 'CHANNEL_ERROR') {
        clearTimeout(timer);
        reject(
          new Error(
            `Realtime channel ${name} failed with ${status}${error?.message ? `: ${error.message}` : ''}`,
          ),
        );
      }
    });
  });

  const capture: CaptureContext = {
    name,
    client,
    channel,
    events,
    mark() {
      return events.length;
    },
    async waitFor(predicate, description, options = {}) {
      const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
      const since = options.since ?? 0;
      const deadline = Date.now() + timeoutMs;
      while (Date.now() < deadline) {
        const match = events.slice(since).find(predicate);
        if (match) {
          return match;
        }
        await sleep(POLL_INTERVAL_MS);
      }

      const recent = events
        .slice(Math.max(0, events.length - 10))
        .map((event) => `${event.table}:${event.eventType}:${stringifyId(event.new.id ?? event.old.id)}`)
        .join(', ');
      throw new Error(
        `Timed out waiting for ${description} on ${name}. Recent events: ${recent || 'none'}`,
      );
    },
    async expectNoMatch(predicate, description, options = {}) {
      const timeoutMs = options.timeoutMs ?? ABSENCE_TIMEOUT_MS;
      const since = options.since ?? 0;
      const deadline = Date.now() + timeoutMs;
      while (Date.now() < deadline) {
        const match = events.slice(since).find(predicate);
        if (match) {
          throw new Error(
            `Unexpected realtime event for ${description} on ${name}: ${match.table}:${match.eventType}:${stringifyId(match.new.id ?? match.old.id)}`,
          );
        }
        await sleep(POLL_INTERVAL_MS);
      }
    },
    async close() {
      await channel.unsubscribe();
      await client.removeChannel(channel);
    },
  };

  context.subscriptions.push(capture);
  return capture;
}

async function cleanup(context: ValidationContext): Promise<void> {
  for (const capture of [...context.subscriptions].reverse()) {
    try {
      await capture.close();
    } catch {
      // Ignore cleanup failures.
    }
  }
  context.subscriptions.length = 0;

  const clubIds = [...new Set(context.clubIds.map((value) => stringifyId(value)).filter(Boolean))];
  const userIds = [...new Set(context.users.map((user) => user.session.user.id).filter(Boolean))];

  const service = context.serviceClient;
  const deleteByClub = async (table: string) => {
    if (clubIds.length === 0) {
      return;
    }

    await service.from(table).delete().in('club_id', clubIds);
  };

  const deleteByUser = async (table: string, column: string) => {
    if (userIds.length === 0) {
      return;
    }

    await service.from(table).delete().in(column, userIds);
  };

  try {
    await deleteByClub('lineup_players');
    await deleteByClub('lineups');
    await deleteByClub('attendance_entries');
    await deleteByClub('attendance_weeks');
    await deleteByClub('stream_links');
    await deleteByClub('leave_requests');
    await deleteByClub('join_requests');
    await deleteByClub('memberships');
    await deleteByClub('club_settings');
    await deleteByClub('club_permission_settings');
    await deleteByClub('club_membership_events');
    await deleteByClub('player_profiles');
    if (clubIds.length > 0) {
      await service.from('clubs').delete().in('id', clubIds);
    }
    await deleteByUser('player_profiles', 'auth_user_id');
    await deleteByUser('memberships', 'auth_user_id');
    await deleteByUser('join_requests', 'requester_user_id');
    await deleteByUser('leave_requests', 'requested_by_user_id');
  } catch {
    // Keep going with auth cleanup.
  }

  for (const userId of userIds) {
    try {
      await service.auth.admin.deleteUser(userId);
    } catch {
      // Ignore cleanup failures.
    }
  }
}

async function runRealtimeAssertion(
  state: RealtimeAuditState,
  description: string,
  operation: () => Promise<void>,
): Promise<void> {
  if (!state.working) {
    return;
  }

  try {
    await operation();
  } catch (error) {
    state.working = false;
    const message =
      error instanceof Error ? error.message : `Unknown realtime failure during ${description}`;
    state.issues.push(`${description}: ${message}`);
    console.warn(`\n[clubline-e2e] realtime issue: ${description}: ${message}`);
  }
}

async function main(): Promise<void> {
  const backendBaseUrl =
    process.env.BACKEND_BASE_URL ??
    `http://127.0.0.1:${process.env.VALIDATION_BACKEND_PORT ?? '3001'}/api`;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const supabaseUrl = process.env.SUPABASE_URL;
  assert(serviceRoleKey, 'SUPABASE_SERVICE_ROLE_KEY is required to run the real validation.');
  assert(supabaseUrl, 'SUPABASE_URL is required to run the real validation.');

  const context: ValidationContext = {
    backendBaseUrl,
    publicConfig: {
      supabase: {
        url: '',
        anonKey: '',
      },
      realtime: {
        provider: '',
        localFallbackEnabled: true,
      },
    },
    serviceClient: createSupabaseClient(supabaseUrl, serviceRoleKey),
    runId: `${Date.now()}-${randomUUID().slice(0, 8)}`,
    users: [],
    clubIds: [],
    subscriptions: [],
  };

  try {
    logStep(`Using backend ${backendBaseUrl}`);

    const health = await backendRequest<{ status: string; service: string }>(backendBaseUrl, '/health');
    assert.equal(health.status, 'ok', 'Backend health check failed');
    assert.equal(health.service, 'clubline-backend', 'Unexpected backend identity on health check');

    const publicConfig = await backendRequest<PublicConfigResponse>(
      backendBaseUrl,
      '/auth/public-config',
    );
    context.publicConfig = publicConfig;
    assert.equal(publicConfig.realtime.provider, 'supabase');
    assert.equal(
      publicConfig.realtime.localFallbackEnabled,
      false,
      'Production-like validation must run with local realtime fallback disabled.',
    );
    const realtimeAudit: RealtimeAuditState = {
      working: true,
      issues: [],
    };

    logStep('Registering four real auth users through the backend');
    const captainA = await registerUser(context, 'captain-a');
    const captainB = await registerUser(context, 'captain-b');
    const playerA = await registerUser(context, 'player-a');
    const outsiderA = await registerUser(context, 'outsider-a');

    logStep('Validating login flow on a freshly created account');
    await verifyLogin(context, captainA);

    logStep('Verifying local SSE fallback is disabled while production realtime remains available');
    await expectBackendError(backendBaseUrl, '/realtime/session', {
      method: 'POST',
      token: captainA.session.accessToken,
      expectedStatus: 410,
      expectedCode: 'local_realtime_disabled',
    });

    logStep('Creating two clubs through the hardened backend workflow');
    const captainAClubCreate = await backendRequest<{
      club: ClubRecord;
      membership: MembershipRecord;
    }>(backendBaseUrl, '/clubs', {
      method: 'POST',
      token: captainA.session.accessToken,
      expectedStatus: 201,
      body: {
        name: `Clubline Alpha ${context.runId}`,
        owner_nome: 'Captain',
        owner_cognome: 'Alpha',
        owner_id_console: `captain-alpha-${context.runId}`,
        owner_shirt_number: 10,
        owner_primary_role: 'CDC',
        primary_color: '#1274FF',
        accent_color: '#00D4C6',
        surface_color: '#12384E',
      },
    });
    const captainBClubCreate = await backendRequest<{
      club: ClubRecord;
      membership: MembershipRecord;
    }>(backendBaseUrl, '/clubs', {
      method: 'POST',
      token: captainB.session.accessToken,
      expectedStatus: 201,
      body: {
        name: `Clubline Beta ${context.runId}`,
        owner_nome: 'Captain',
        owner_cognome: 'Beta',
        owner_id_console: `captain-beta-${context.runId}`,
        owner_shirt_number: 9,
        owner_primary_role: 'ATT',
        primary_color: '#A53DFF',
        accent_color: '#FFB020',
        surface_color: '#1E1E2A',
      },
    });
    const clubA = captainAClubCreate.club;
    const clubB = captainBClubCreate.club;
    context.clubIds.push(clubA.id, clubB.id);

    logStep('Checking direct RLS reads and unauthorized direct mutation attempts');
    const captainAVisibleClubs = ensureSupabaseSuccess(
      await captainA.client.from('clubs').select('id,name,slug').order('name', { ascending: true }),
      'captainA direct clubs read',
    ) as ClubRecord[];
    assert.deepEqual(
      captainAVisibleClubs.map((club) => stringifyId(club.id)),
      [stringifyId(clubA.id)],
      'Captain A should only see club A through direct Supabase reads.',
    );

    const captainBVisibleClubs = ensureSupabaseSuccess(
      await captainB.client.from('clubs').select('id,name,slug').order('name', { ascending: true }),
      'captainB direct clubs read',
    ) as ClubRecord[];
    assert.deepEqual(
      captainBVisibleClubs.map((club) => stringifyId(club.id)),
      [stringifyId(clubB.id)],
      'Captain B should only see club B through direct Supabase reads.',
    );

    const playerVisibleClubsBeforeJoin = ensureSupabaseSuccess(
      await playerA.client.from('clubs').select('id,name'),
      'playerA direct clubs read before joining',
    ) as ClubRecord[];
    assert.equal(playerVisibleClubsBeforeJoin.length, 0, 'A user without a club should not see clubs directly.');

    const captainBCrossClubRequests = ensureSupabaseSuccess(
      await captainB.client.from('join_requests').select('id,club_id').eq('club_id', clubA.id),
      'captainB cross-club join request read',
    ) as JoinRequestRecord[];
    assert.equal(captainBCrossClubRequests.length, 0, 'Captain B should not see join requests for club A.');

    const captainBCrossClubMemberships = ensureSupabaseSuccess(
      await captainB.client.from('memberships').select('id,club_id').eq('club_id', clubA.id),
      'captainB cross-club memberships read',
    ) as MembershipRecord[];
    assert.equal(captainBCrossClubMemberships.length, 0, 'Captain B should not see memberships for club A.');

    const unsafeMembershipInsertError = ensureSupabaseFailure(
      await playerA.client.from('memberships').insert({
        club_id: clubA.id,
        auth_user_id: playerA.session.user.id,
        role: 'captain',
        status: 'active',
      }),
      'direct membership insert as authenticated user',
    );
    assert(
      unsafeMembershipInsertError.code === '42501' ||
        /permission|row-level|policy/i.test(unsafeMembershipInsertError.message),
      `Unexpected error for blocked membership insert: ${unsafeMembershipInsertError.code} ${unsafeMembershipInsertError.message}`,
    );

    logStep('Opening scoped Supabase Realtime subscriptions for join flow');
    const captainAJoinCapture = await subscribeToChanges(context, captainA.client, 'captain-a-join', [
      { table: 'join_requests', filter: `club_id=eq.${stringifyId(clubA.id)}` },
    ]);
    const captainBJoinCapture = await subscribeToChanges(context, captainB.client, 'captain-b-join', [
      { table: 'join_requests', filter: `club_id=eq.${stringifyId(clubB.id)}` },
    ]);
    const playerAOwnJoinCapture = await subscribeToChanges(context, playerA.client, 'player-a-own-join', [
      {
        table: 'join_requests',
        filter: `requester_user_id=eq.${playerA.session.user.id}`,
      },
    ]);
    const playerAMembershipCapture = await subscribeToChanges(context, playerA.client, 'player-a-membership', [
      {
        table: 'memberships',
        filter: `auth_user_id=eq.${playerA.session.user.id}`,
      },
    ]);

    const captainAJoinCheckpoint = captainAJoinCapture.mark();
    const captainBJoinCheckpoint = captainBJoinCapture.mark();
    const playerAJoinCheckpoint = playerAOwnJoinCapture.mark();
    const playerAMembershipCheckpoint = playerAMembershipCapture.mark();

    logStep('Submitting a real join request and validating scoped realtime delivery');
    const playerJoin = await backendRequest<{ joinRequest: JoinRequestRecord }>(
      backendBaseUrl,
      '/clubs/join-requests',
      {
        method: 'POST',
        token: playerA.session.accessToken,
        expectedStatus: 201,
        body: {
          club_id: clubA.id,
          requested_nome: 'Player',
          requested_cognome: 'Alpha',
          requested_shirt_number: 21,
          requested_primary_role: 'ED',
        },
      },
    );
    const playerJoinRequestId = stringifyId(playerJoin.joinRequest.id);

    const captainAVisibleJoinRequests = ensureSupabaseSuccess(
      await captainA.client
        .from('join_requests')
        .select('id,club_id,status')
        .eq('club_id', clubA.id)
        .eq('status', 'pending'),
      'captainA pending join request read after insert',
    ) as JoinRequestRecord[];
    assert(
      captainAVisibleJoinRequests.some((row) => stringifyId(row.id) === playerJoinRequestId),
      'Captain A should be able to read the pending join request directly through RLS.',
    );

    await runRealtimeAssertion(realtimeAudit, 'captain A join request insert', async () => {
      await captainAJoinCapture.waitFor(
        (event) =>
          event.table === 'join_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === playerJoinRequestId,
        'captain A join request insert',
        { since: captainAJoinCheckpoint },
      );
    });
    await runRealtimeAssertion(realtimeAudit, 'player A own join request insert', async () => {
      await playerAOwnJoinCapture.waitFor(
        (event) =>
          event.table === 'join_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === playerJoinRequestId,
        'player A own join request insert',
        { since: playerAJoinCheckpoint },
      );
    });
    await runRealtimeAssertion(
      realtimeAudit,
      'captain B should not receive club A join request events',
      async () => {
        await captainBJoinCapture.expectNoMatch(
          (event) => stringifyId(event.new.id) === playerJoinRequestId,
          'captain B should not receive club A join request events',
          { since: captainBJoinCheckpoint },
        );
      },
    );

    await expectBackendError(backendBaseUrl, `/clubs/join-requests/${playerJoinRequestId}/approve`, {
      method: 'POST',
      token: playerA.session.accessToken,
      expectedStatus: 403,
    });
    await expectBackendError(backendBaseUrl, `/clubs/join-requests/${playerJoinRequestId}/approve`, {
      method: 'POST',
      token: captainB.session.accessToken,
      expectedStatus: 403,
    });

    const approvedJoin = await backendRequest<{ membership: MembershipRecord }>(
      backendBaseUrl,
      `/clubs/join-requests/${playerJoinRequestId}/approve`,
      {
        method: 'POST',
        token: captainA.session.accessToken,
      },
    );
    const playerMembershipId = stringifyId(approvedJoin.membership.id);

    await runRealtimeAssertion(realtimeAudit, 'player A membership insert after join approval', async () => {
      await playerAMembershipCapture.waitFor(
        (event) =>
          event.table === 'memberships' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === playerMembershipId,
        'player A membership insert after join approval',
        { since: playerAMembershipCheckpoint },
      );
    });
    await runRealtimeAssertion(realtimeAudit, 'player A join request approved update', async () => {
      await playerAOwnJoinCapture.waitFor(
        (event) =>
          event.table === 'join_requests' &&
          event.eventType === 'UPDATE' &&
          stringifyId(event.new.id) === playerJoinRequestId &&
          event.new.status === 'approved',
        'player A join request approved update',
        { since: playerAJoinCheckpoint },
      );
    });

    await expectBackendError(backendBaseUrl, `/clubs/join-requests/${playerJoinRequestId}/approve`, {
      method: 'POST',
      token: captainA.session.accessToken,
      expectedStatus: 409,
    });
    await expectBackendError(backendBaseUrl, '/clubs/join-requests', {
      method: 'POST',
      token: playerA.session.accessToken,
      body: { club_id: clubA.id },
      expectedStatus: 409,
    });

    const activeMembershipsForPlayer = ensureSupabaseSuccess(
      await context.serviceClient
        .from('memberships')
        .select('id,club_id,auth_user_id,status')
        .eq('auth_user_id', playerA.session.user.id)
        .eq('status', 'active'),
      'service-role active memberships query for player A',
    ) as MembershipRecord[];
    assert.equal(activeMembershipsForPlayer.length, 1, 'Player A must have exactly one active membership after approval.');

    const playerVisibleClubsAfterJoin = ensureSupabaseSuccess(
      await playerA.client.from('clubs').select('id,name,slug'),
      'playerA direct clubs read after joining',
    ) as ClubRecord[];
    assert.deepEqual(
      playerVisibleClubsAfterJoin.map((club) => stringifyId(club.id)),
      [stringifyId(clubA.id)],
      'Player A should only see club A after joining.',
    );

    logStep('Validating self profile update and club-scoped lineups CRUD with realtime');
    const playerMe = await backendRequest<{ player: PlayerRecord | null }>(
      backendBaseUrl,
      '/players/me',
      {
        token: playerA.session.accessToken,
      },
    );
    assert(playerMe.player, 'Player A should have a player profile after join approval.');
    const playerARecordId = stringifyId(playerMe.player.id);

    const updatedPlayer = await backendRequest<{ player: PlayerRecord }>(
      backendBaseUrl,
      `/players/${playerARecordId}`,
      {
        method: 'PATCH',
        token: playerA.session.accessToken,
        body: {
          nome: 'Player',
          cognome: 'Alpha',
          account_email: playerA.email,
          shirt_number: 19,
          primary_role: 'CDC',
          secondary_roles: ['CC'],
          id_console: `player-alpha-${context.runId}`,
        },
      },
    );
    assert.equal(updatedPlayer.player.shirt_number, 19, 'Player update should persist new shirt number.');

    const playerALineupsCapture = await subscribeToChanges(context, playerA.client, 'player-a-lineups', [
      { table: 'lineups', filter: `club_id=eq.${stringifyId(clubA.id)}` },
    ]);
    const playerALineupPlayersCapture = await subscribeToChanges(
      context,
      playerA.client,
      'player-a-lineup-players',
      [{ table: 'lineup_players', filter: `club_id=eq.${stringifyId(clubA.id)}` }],
    );
    const captainBLineupsCapture = await subscribeToChanges(context, captainB.client, 'captain-b-lineups', [
      { table: 'lineups', filter: `club_id=eq.${stringifyId(clubB.id)}` },
    ]);

    const playerALineupsCheckpoint = playerALineupsCapture.mark();
    const playerALineupPlayersCheckpoint = playerALineupPlayersCapture.mark();
    const captainBLineupsCheckpoint = captainBLineupsCapture.mark();

    const createdLineup = await backendRequest<{ lineup: LineupRecord }>(
      backendBaseUrl,
      '/lineups',
      {
        method: 'POST',
        token: captainA.session.accessToken,
        expectedStatus: 201,
        body: {
          competition_name: 'Serie A',
          match_datetime: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
          opponent_name: 'Inter',
          formation_module: '4-3-3 IN LINEA',
          notes: 'Initial lineup',
        },
      },
    );
    const lineupId = stringifyId(createdLineup.lineup.id);

    await runRealtimeAssertion(realtimeAudit, 'lineup create event for player A', async () => {
      await playerALineupsCapture.waitFor(
        (event) =>
          event.table === 'lineups' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === lineupId,
        'lineup create event for player A',
        { since: playerALineupsCheckpoint },
      );
    });
    await runRealtimeAssertion(realtimeAudit, 'captain B should not receive lineups from club A', async () => {
      await captainBLineupsCapture.expectNoMatch(
        (event) => stringifyId(event.new.id) === lineupId,
        'captain B should not receive lineups from club A',
        { since: captainBLineupsCheckpoint },
      );
    });

    await backendRequest<null>(backendBaseUrl, `/lineups/${lineupId}/players`, {
      method: 'PUT',
      token: captainA.session.accessToken,
      expectedStatus: 204,
      body: {
        assignments: [
          {
            player_id: playerARecordId,
            position_code: 'AS',
          },
        ],
      },
    });
    await runRealtimeAssertion(realtimeAudit, 'lineup player assignment event for player A', async () => {
      await playerALineupPlayersCapture.waitFor(
        (event) =>
          event.table === 'lineup_players' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.lineup_id) === lineupId &&
          stringifyId(event.new.player_id) === playerARecordId,
        'lineup player assignment event for player A',
        { since: playerALineupPlayersCheckpoint },
      );
    });

    const crossClubLineupRead = ensureSupabaseSuccess(
      await captainB.client
        .from('lineup_players')
        .select('id,lineup_id,player_id,club_id')
        .eq('club_id', clubA.id),
      'captainB cross-club lineup players read',
    ) as Array<{ id: string | number }>;
    assert.equal(crossClubLineupRead.length, 0, 'Captain B should not read lineup players for club A.');

    const lineupUpdateCheckpoint = playerALineupsCapture.mark();
    await backendRequest<{ lineup: LineupRecord }>(backendBaseUrl, `/lineups/${lineupId}`, {
      method: 'PUT',
      token: captainA.session.accessToken,
      body: {
        competition_name: 'Serie A',
        match_datetime: new Date(Date.now() + 90 * 60 * 1000).toISOString(),
        opponent_name: 'Inter',
        formation_module: '4-2-3-1 STRETTO',
        notes: 'Updated lineup',
      },
    });
    await runRealtimeAssertion(realtimeAudit, 'lineup update event for player A', async () => {
      await playerALineupsCapture.waitFor(
        (event) =>
          event.table === 'lineups' &&
          event.eventType === 'UPDATE' &&
          stringifyId(event.new.id) === lineupId &&
          event.new.notes === 'Updated lineup',
        'lineup update event for player A',
        { since: lineupUpdateCheckpoint },
      );
    });

    const lineupDeleteCheckpoint = playerALineupsCapture.mark();
    await backendRequest<null>(backendBaseUrl, `/lineups/${lineupId}`, {
      method: 'DELETE',
      token: captainA.session.accessToken,
      expectedStatus: 204,
    });
    await runRealtimeAssertion(realtimeAudit, 'lineup delete event for player A', async () => {
      await playerALineupsCapture.waitFor(
        (event) =>
          event.table === 'lineups' &&
          event.eventType === 'DELETE' &&
          stringifyId(event.old.id) === lineupId,
        'lineup delete event for player A',
        { since: lineupDeleteCheckpoint },
      );
    });

    await expectBackendError(backendBaseUrl, '/lineups', {
      method: 'POST',
      token: playerA.session.accessToken,
      body: {
        competition_name: 'Serie A',
        match_datetime: new Date().toISOString(),
        opponent_name: 'Roma',
        formation_module: '4-4-2 IN LINEA',
      },
      expectedStatus: 403,
    });

    logStep('Validating reject path for join requests under realtime and permission rules');
    const outsiderOwnJoinCapture = await subscribeToChanges(context, outsiderA.client, 'outsider-own-join', [
      {
        table: 'join_requests',
        filter: `requester_user_id=eq.${outsiderA.session.user.id}`,
      },
    ]);
    const outsiderJoinCheckpoint = outsiderOwnJoinCapture.mark();
    const captainAJoinCheckpoint2 = captainAJoinCapture.mark();
    const captainBJoinCheckpoint2 = captainBJoinCapture.mark();

    const outsiderJoin = await backendRequest<{ joinRequest: JoinRequestRecord }>(
      backendBaseUrl,
      '/clubs/join-requests',
      {
        method: 'POST',
        token: outsiderA.session.accessToken,
        expectedStatus: 201,
        body: {
          club_id: clubA.id,
          requested_nome: 'Outsider',
          requested_cognome: 'Alpha',
          requested_shirt_number: 77,
          requested_primary_role: 'POR',
        },
      },
    );
    const outsiderJoinRequestId = stringifyId(outsiderJoin.joinRequest.id);

    await runRealtimeAssertion(realtimeAudit, 'captain A outsider join request insert', async () => {
      await captainAJoinCapture.waitFor(
        (event) =>
          event.table === 'join_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === outsiderJoinRequestId,
        'captain A outsider join request insert',
        { since: captainAJoinCheckpoint2 },
      );
    });
    await runRealtimeAssertion(realtimeAudit, 'outsider own join request insert', async () => {
      await outsiderOwnJoinCapture.waitFor(
        (event) =>
          event.table === 'join_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === outsiderJoinRequestId,
        'outsider own join request insert',
        { since: outsiderJoinCheckpoint },
      );
    });
    await runRealtimeAssertion(
      realtimeAudit,
      'captain B should not receive outsider join request for club A',
      async () => {
        await captainBJoinCapture.expectNoMatch(
          (event) => stringifyId(event.new.id) === outsiderJoinRequestId,
          'captain B should not receive outsider join request for club A',
          { since: captainBJoinCheckpoint2 },
        );
      },
    );

    await expectBackendError(backendBaseUrl, '/clubs/join-requests/pending', {
      method: 'GET',
      token: playerA.session.accessToken,
      expectedStatus: 403,
    });
    await expectBackendError(backendBaseUrl, `/clubs/join-requests/${outsiderJoinRequestId}/reject`, {
      method: 'POST',
      token: playerA.session.accessToken,
      expectedStatus: 403,
    });

    const directJoinApproveError = ensureSupabaseFailure(
      await outsiderA.client
        .from('join_requests')
        .update({ status: 'approved' })
        .eq('id', outsiderJoinRequestId),
      'direct join request approval via Supabase client',
    );
    assert(
      directJoinApproveError.code === '42501' ||
        /permission|policy/i.test(directJoinApproveError.message),
      `Unexpected direct join approval error: ${directJoinApproveError.code} ${directJoinApproveError.message}`,
    );

    await backendRequest<null>(backendBaseUrl, `/clubs/join-requests/${outsiderJoinRequestId}/reject`, {
      method: 'POST',
      token: captainA.session.accessToken,
      expectedStatus: 204,
    });
    await runRealtimeAssertion(realtimeAudit, 'outsider rejected join request update', async () => {
      await outsiderOwnJoinCapture.waitFor(
        (event) =>
          event.table === 'join_requests' &&
          event.eventType === 'UPDATE' &&
          stringifyId(event.new.id) === outsiderJoinRequestId &&
          event.new.status === 'rejected',
        'outsider rejected join request update',
        { since: outsiderJoinCheckpoint },
      );
    });

    const outsiderActiveMemberships = ensureSupabaseSuccess(
      await context.serviceClient
        .from('memberships')
        .select('id')
        .eq('auth_user_id', outsiderA.session.user.id)
        .eq('status', 'active'),
      'service-role active memberships query for outsider',
    ) as Array<{ id: string | number }>;
    assert.equal(outsiderActiveMemberships.length, 0, 'Rejected join request must not create memberships.');

    logStep('Validating captain leave edge case and leave request reject/approve flow');
    await expectBackendError(backendBaseUrl, '/clubs/leave-requests', {
      method: 'POST',
      token: captainA.session.accessToken,
      expectedStatus: 409,
    });

    const captainALeaveCapture = await subscribeToChanges(context, captainA.client, 'captain-a-leave', [
      { table: 'leave_requests', filter: `club_id=eq.${stringifyId(clubA.id)}` },
    ]);
    const playerALeaveCapture = await subscribeToChanges(context, playerA.client, 'player-a-leave', [
      {
        table: 'leave_requests',
        filter: `requested_by_user_id=eq.${playerA.session.user.id}`,
      },
    ]);
    const playerAMembershipCheckpoint2 = playerAMembershipCapture.mark();
    const captainALeaveCheckpoint = captainALeaveCapture.mark();
    const playerALeaveCheckpoint = playerALeaveCapture.mark();

    const leaveRequested = await backendRequest<{ leaveRequest: LeaveRequestRecord }>(
      backendBaseUrl,
      '/clubs/leave-requests',
      {
        method: 'POST',
        token: playerA.session.accessToken,
        expectedStatus: 201,
      },
    );
    const leaveRequestId = stringifyId(leaveRequested.leaveRequest.id);

    await runRealtimeAssertion(realtimeAudit, 'captain A leave request insert', async () => {
      await captainALeaveCapture.waitFor(
        (event) =>
          event.table === 'leave_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === leaveRequestId,
        'captain A leave request insert',
        { since: captainALeaveCheckpoint },
      );
    });
    await runRealtimeAssertion(realtimeAudit, 'player A own leave request insert', async () => {
      await playerALeaveCapture.waitFor(
        (event) =>
          event.table === 'leave_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === leaveRequestId,
        'player A own leave request insert',
        { since: playerALeaveCheckpoint },
      );
    });

    await expectBackendError(backendBaseUrl, `/clubs/leave-requests/${leaveRequestId}/approve`, {
      method: 'POST',
      token: captainB.session.accessToken,
      expectedStatus: 403,
    });

    await backendRequest<null>(backendBaseUrl, `/clubs/leave-requests/${leaveRequestId}/reject`, {
      method: 'POST',
      token: captainA.session.accessToken,
      expectedStatus: 204,
    });
    await runRealtimeAssertion(realtimeAudit, 'player A leave request rejected update', async () => {
      await playerALeaveCapture.waitFor(
        (event) =>
          event.table === 'leave_requests' &&
          event.eventType === 'UPDATE' &&
          stringifyId(event.new.id) === leaveRequestId &&
          event.new.status === 'rejected',
        'player A leave request rejected update',
        { since: playerALeaveCheckpoint },
      );
    });

    const stillActiveAfterReject = ensureSupabaseSuccess(
      await context.serviceClient
        .from('memberships')
        .select('id, status')
        .eq('id', playerMembershipId)
        .maybeSingle(),
      'membership status after rejected leave request',
    ) as MembershipRecord | null;
    assert(stillActiveAfterReject, 'Membership should still exist after rejected leave request.');
    assert.equal(stillActiveAfterReject.status, 'active');

    const captainALeaveCheckpoint2 = captainALeaveCapture.mark();
    const playerALeaveCheckpoint2 = playerALeaveCapture.mark();
    const playerAMembershipCheckpoint3 = playerAMembershipCapture.mark();

    const leaveRequestedAgain = await backendRequest<{ leaveRequest: LeaveRequestRecord }>(
      backendBaseUrl,
      '/clubs/leave-requests',
      {
        method: 'POST',
        token: playerA.session.accessToken,
        expectedStatus: 201,
      },
    );
    const leaveRequestId2 = stringifyId(leaveRequestedAgain.leaveRequest.id);

    await runRealtimeAssertion(realtimeAudit, 'captain A second leave request insert', async () => {
      await captainALeaveCapture.waitFor(
        (event) =>
          event.table === 'leave_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === leaveRequestId2,
        'captain A second leave request insert',
        { since: captainALeaveCheckpoint2 },
      );
    });
    await runRealtimeAssertion(realtimeAudit, 'player A second leave request insert', async () => {
      await playerALeaveCapture.waitFor(
        (event) =>
          event.table === 'leave_requests' &&
          event.eventType === 'INSERT' &&
          stringifyId(event.new.id) === leaveRequestId2,
        'player A second leave request insert',
        { since: playerALeaveCheckpoint2 },
      );
    });

    await backendRequest<null>(backendBaseUrl, `/clubs/leave-requests/${leaveRequestId2}/approve`, {
      method: 'POST',
      token: captainA.session.accessToken,
      expectedStatus: 204,
    });
    await runRealtimeAssertion(realtimeAudit, 'player A leave request approved update', async () => {
      await playerALeaveCapture.waitFor(
        (event) =>
          event.table === 'leave_requests' &&
          event.eventType === 'UPDATE' &&
          stringifyId(event.new.id) === leaveRequestId2 &&
          event.new.status === 'approved',
        'player A leave request approved update',
        { since: playerALeaveCheckpoint2 },
      );
    });
    await runRealtimeAssertion(realtimeAudit, 'player A membership marked left', async () => {
      await playerAMembershipCapture.waitFor(
        (event) =>
          event.table === 'memberships' &&
          event.eventType === 'UPDATE' &&
          stringifyId(event.new.id) === playerMembershipId &&
          event.new.status === 'left',
        'player A membership marked left',
        { since: playerAMembershipCheckpoint3 },
      );
    });

    const playerVisibleClubsAfterLeave = ensureSupabaseSuccess(
      await playerA.client.from('clubs').select('id,name'),
      'playerA direct clubs read after leave approval',
    ) as ClubRecord[];
    assert.equal(playerVisibleClubsAfterLeave.length, 0, 'Player A should no longer see club data after leaving.');

    const activeMembershipsAfterLeave = ensureSupabaseSuccess(
      await context.serviceClient
        .from('memberships')
        .select('id')
        .eq('auth_user_id', playerA.session.user.id)
        .eq('status', 'active'),
      'active membership count after leave approval',
    ) as Array<{ id: string | number }>;
    assert.equal(activeMembershipsAfterLeave.length, 0, 'Player A should not have active memberships after approved leave.');

    logStep('Deleting clubs through the backend after membership cleanup');
    await backendRequest<null>(backendBaseUrl, '/clubs/current', {
      method: 'DELETE',
      token: captainA.session.accessToken,
      expectedStatus: 204,
    });
    await backendRequest<null>(backendBaseUrl, '/clubs/current', {
      method: 'DELETE',
      token: captainB.session.accessToken,
      expectedStatus: 204,
    });

    const clubsRemaining = ensureSupabaseSuccess(
      await context.serviceClient
        .from('clubs')
        .select('id')
        .in('id', [clubA.id, clubB.id]),
      'remaining test clubs lookup',
    ) as Array<{ id: string | number }>;
    assert.equal(clubsRemaining.length, 0, 'Test clubs should be deleted by the end of the validation.');
    context.clubIds.length = 0;

    if (realtimeAudit.issues.length > 0) {
      throw new Error(
        `Realtime validation issues:\n- ${realtimeAudit.issues.join('\n- ')}`,
      );
    }

    logStep('Real Supabase production-path validation completed successfully');
    console.log(
      JSON.stringify(
        {
          backendBaseUrl,
          runId: context.runId,
          validated: [
            'backend auth register/login against real Supabase Auth',
            'local SSE fallback disabled while Supabase Realtime remains functional',
            'club-scoped RLS reads on clubs, memberships, join_requests, lineup_players',
            'join approve/reject with realtime delivery to correct scoped clients',
            'leave reject/approve with realtime delivery and membership state transitions',
            'captain-only operations and captain leave edge case enforcement',
            'club-scoped lineups create/update/delete plus lineup_players realtime',
            'direct unauthorized writes blocked at the database layer',
          ],
        },
        null,
        2,
      ),
    );
  } finally {
    await cleanup(context);
  }
}

void main().catch((error) => {
  console.error('\n[clubline-e2e] Validation failed');
  console.error(error);
  process.exitCode = 1;
});
