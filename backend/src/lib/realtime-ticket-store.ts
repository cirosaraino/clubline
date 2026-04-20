import { randomUUID } from 'crypto';

type RealtimeTicketRecord = {
  ticket: string;
  userId: string;
  issuedAt: number;
  expiresAt: number;
};

const REALTIME_TICKET_TTL_MS = 10 * 60 * 1000;

class RealtimeTicketStore {
  private readonly tickets = new Map<string, RealtimeTicketRecord>();

  issue(userId: string): RealtimeTicketRecord {
    this.cleanupExpired();

    const now = Date.now();
    const record: RealtimeTicketRecord = {
      ticket: randomUUID(),
      userId,
      issuedAt: now,
      expiresAt: now + REALTIME_TICKET_TTL_MS,
    };

    this.tickets.set(record.ticket, record);
    return record;
  }

  validate(ticket: string): RealtimeTicketRecord | null {
    const normalizedTicket = ticket.trim();
    if (normalizedTicket.length == 0) {
      return null;
    }

    const record = this.tickets.get(normalizedTicket);
    if (!record) {
      return null;
    }

    if (record.expiresAt <= Date.now()) {
      this.tickets.delete(normalizedTicket);
      return null;
    }

    return record;
  }

  cleanupExpired(): void {
    const now = Date.now();
    for (const [ticket, record] of this.tickets.entries()) {
      if (record.expiresAt <= now) {
        this.tickets.delete(ticket);
      }
    }
  }
}

export const realtimeTicketStore = new RealtimeTicketStore();
