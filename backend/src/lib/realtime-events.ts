import { EventEmitter } from 'events';

export type RealtimeScope =
  | 'players'
  | 'streams'
  | 'lineups'
  | 'attendance'
  | 'teamInfo'
  | 'vicePermissions';

export type RealtimeChange = {
  revision: number;
  scopes: RealtimeScope[];
  reason: string;
  timestamp: string;
};

type ChangeListener = (change: RealtimeChange) => void;

class RealtimeEventsBus {
  private readonly emitter = new EventEmitter();
  private revision = 0;
  private latestChange: RealtimeChange | null = null;

  constructor() {
    this.emitter.setMaxListeners(0);
  }

  publishChange(scopes: RealtimeScope[], reason = 'updated'): RealtimeChange {
    const uniqueScopes = Array.from(new Set(scopes));
    this.revision += 1;

    const change: RealtimeChange = {
      revision: this.revision,
      scopes: uniqueScopes,
      reason,
      timestamp: new Date().toISOString(),
    };

    this.latestChange = change;
    this.emitter.emit('change', change);

    return change;
  }

  getLatestChange(): RealtimeChange | null {
    return this.latestChange;
  }

  subscribe(listener: ChangeListener): () => void {
    this.emitter.on('change', listener);

    return () => {
      this.emitter.off('change', listener);
    };
  }
}

export const realtimeEventsBus = new RealtimeEventsBus();
