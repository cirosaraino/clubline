import { EventEmitter } from 'events';

export type LocalRealtimeScope =
  | 'clubs'
  | 'players'
  | 'streams'
  | 'lineups'
  | 'attendance'
  | 'teamInfo'
  | 'vicePermissions';

export type LocalRealtimeChange = {
  revision: number;
  scopes: LocalRealtimeScope[];
  reason: string;
  timestamp: string;
};

type ChangeListener = (change: LocalRealtimeChange) => void;

class LocalRealtimeEventsBus {
  private readonly emitter = new EventEmitter();
  private revision = 0;
  private latestChange: LocalRealtimeChange | null = null;

  constructor() {
    this.emitter.setMaxListeners(0);
  }

  publishChange(
    scopes: LocalRealtimeScope[],
    reason = 'updated',
  ): LocalRealtimeChange {
    const uniqueScopes = Array.from(new Set(scopes));
    this.revision += 1;

    const change: LocalRealtimeChange = {
      revision: this.revision,
      scopes: uniqueScopes,
      reason,
      timestamp: new Date().toISOString(),
    };

    this.latestChange = change;
    this.emitter.emit('change', change);

    return change;
  }

  getLatestChange(): LocalRealtimeChange | null {
    return this.latestChange;
  }

  subscribe(listener: ChangeListener): () => void {
    this.emitter.on('change', listener);

    return () => {
      this.emitter.off('change', listener);
    };
  }
}

export const localRealtimeEventsBus = new LocalRealtimeEventsBus();

export type RealtimeScope = LocalRealtimeScope;
export type RealtimeChange = LocalRealtimeChange;

/**
 * @deprecated Use localRealtimeEventsBus through realtime-publisher.ts.
 * This alias exists only to keep transitional compatibility while routes are consolidated.
 */
export const realtimeEventsBus = localRealtimeEventsBus;
