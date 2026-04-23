import { env } from '../config/env';
import {
  localRealtimeEventsBus,
  type LocalRealtimeChange,
  type LocalRealtimeScope,
} from './realtime-events';

export type AppRealtimeScope = LocalRealtimeScope;
export type AppRealtimeChange = LocalRealtimeChange;

export function publishRealtimeChange(
  scopes: AppRealtimeScope[],
  reason = 'updated',
): AppRealtimeChange | null {
  if (!env.ENABLE_LOCAL_REALTIME_FALLBACK) {
    return null;
  }

  return localRealtimeEventsBus.publishChange(scopes, reason);
}

export function getLatestRealtimeChange(): AppRealtimeChange | null {
  if (!env.ENABLE_LOCAL_REALTIME_FALLBACK) {
    return null;
  }

  return localRealtimeEventsBus.getLatestChange();
}

export function subscribeRealtimeChanges(
  listener: (change: AppRealtimeChange) => void,
): () => void {
  if (!env.ENABLE_LOCAL_REALTIME_FALLBACK) {
    return () => {};
  }

  return localRealtimeEventsBus.subscribe(listener);
}
