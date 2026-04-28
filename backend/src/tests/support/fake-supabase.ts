type Row = Record<string, any>;

type QueryResult<T = any> = {
  data: T | null;
  error: Error | null;
  count?: number | null;
};

type UpsertOptions = {
  onConflict?: string;
  ignoreDuplicates?: boolean;
};

function cloneValue<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function valuesEqual(left: unknown, right: unknown): boolean {
  if (left == null || right == null) {
    return left === right;
  }

  return `${left}` === `${right}`;
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function likeToRegExp(pattern: string, caseInsensitive = false): RegExp {
  const regex = `^${escapeRegex(pattern)
    .replace(/%/g, '.*')
    .replace(/_/g, '.')}$`;
  return new RegExp(regex, caseInsensitive ? 'i' : undefined);
}

export class FakeSupabaseClient {
  private readonly tables: Record<string, Row[]>;
  private readonly idCounters = new Map<string, number>();
  readonly uploadedStoragePaths: string[] = [];
  readonly removedStoragePaths: string[] = [];

  readonly storage = {
    from: (_bucket: string) => ({
      upload: async (path: string) => {
        this.uploadedStoragePaths.push(path);
        return {
          data: { path },
          error: null,
        };
      },
      getPublicUrl: (path: string) => ({
        data: { publicUrl: `https://storage.example.test/${path}` },
      }),
      remove: async (paths: string[]) => {
        this.removedStoragePaths.push(...paths);
        return {
          data: { paths: cloneValue(paths) },
          error: null,
        };
      },
    }),
  };

  constructor(seed: Partial<Record<string, Row[]>> = {}) {
    this.tables = {};

    for (const [table, rows] of Object.entries(seed)) {
      this.tables[table] = cloneValue(rows ?? []);
      const nextId = this.tables[table]
        .map((row) => Number(row.id))
        .filter((value) => Number.isFinite(value))
        .reduce((max, value) => Math.max(max, value), 0);
      this.idCounters.set(table, nextId + 1);
    }
  }

  from(table: string): FakeQueryBuilder {
    if (!this.tables[table]) {
      this.tables[table] = [];
      this.idCounters.set(table, 1);
    }

    return new FakeQueryBuilder(this, table);
  }

  rows<T extends Row = Row>(table: string): T[] {
    return cloneValue((this.tables[table] ?? []) as T[]);
  }

  findById<T extends Row = Row>(table: string, id: unknown): T | null {
    const row = (this.tables[table] ?? []).find((candidate) => valuesEqual(candidate.id, id));
    return row ? cloneValue(row as T) : null;
  }

  getMutableRows(table: string): Row[] {
    if (!this.tables[table]) {
      this.tables[table] = [];
      this.idCounters.set(table, 1);
    }

    return this.tables[table];
  }

  allocateId(table: string): number {
    const nextId = this.idCounters.get(table) ?? 1;
    this.idCounters.set(table, nextId + 1);
    return nextId;
  }
}

class FakeQueryBuilder implements PromiseLike<QueryResult> {
  private operation: 'select' | 'insert' | 'update' | 'delete' | 'upsert' = 'select';
  private selectColumns = '*';
  private expectMode: 'many' | 'single' | 'maybeSingle' = 'many';
  private readonly filters: Array<(row: Row) => boolean> = [];
  private limitValue: number | null = null;
  private rangeWindow: { from: number; to: number } | null = null;
  private orderBy: { column: string; ascending: boolean } | null = null;
  private payload: Row[] | Row | null = null;
  private upsertOptions: UpsertOptions = {};
  private countRequested = false;
  private headRequested = false;
  private executedResult: QueryResult | null = null;

  constructor(
    private readonly db: FakeSupabaseClient,
    private readonly table: string,
  ) {}

  select(columns = '*', options?: { count?: string; head?: boolean }): this {
    this.selectColumns = columns;
    this.countRequested = options?.count === 'exact';
    this.headRequested = Boolean(options?.head);
    return this;
  }

  insert(payload: Row | Row[]): this {
    this.operation = 'insert';
    this.payload = cloneValue(payload);
    return this;
  }

  upsert(payload: Row | Row[], options?: UpsertOptions): this {
    this.operation = 'upsert';
    this.payload = cloneValue(payload);
    this.upsertOptions = options ?? {};
    return this;
  }

  update(payload: Row): this {
    this.operation = 'update';
    this.payload = cloneValue(payload);
    return this;
  }

  delete(): this {
    this.operation = 'delete';
    return this;
  }

  eq(column: string, value: unknown): this {
    this.filters.push((row) => valuesEqual(row[column], value));
    return this;
  }

  neq(column: string, value: unknown): this {
    this.filters.push((row) => !valuesEqual(row[column], value));
    return this;
  }

  is(column: string, value: unknown): this {
    this.filters.push((row) => row[column] === value);
    return this;
  }

  ilike(column: string, pattern: string): this {
    const regex = likeToRegExp(pattern, true);
    this.filters.push((row) => regex.test(`${row[column] ?? ''}`));
    return this;
  }

  in(column: string, values: unknown[]): this {
    const allowedValues = new Set(values.map((value) => `${value}`));
    this.filters.push((row) => allowedValues.has(`${row[column]}`));
    return this;
  }

  or(expression: string): this {
    const clauses = expression
      .split(',')
      .map((clause) => clause.trim())
      .filter(Boolean)
      .map((clause) => this.buildOrPredicate(clause));

    this.filters.push((row) => clauses.some((predicate) => predicate(row)));
    return this;
  }

  order(column: string, options?: { ascending?: boolean }): this {
    this.orderBy = {
      column,
      ascending: options?.ascending !== false,
    };
    return this;
  }

  limit(value: number): this {
    this.limitValue = value;
    return this;
  }

  range(from: number, to: number): this {
    this.rangeWindow = {
      from: Math.max(0, Math.trunc(from)),
      to: Math.max(0, Math.trunc(to)),
    };
    return this;
  }

  single(): Promise<QueryResult> {
    this.expectMode = 'single';
    return this.execute();
  }

  maybeSingle(): Promise<QueryResult> {
    this.expectMode = 'maybeSingle';
    return this.execute();
  }

  then<TResult1 = QueryResult, TResult2 = never>(
    onfulfilled?: ((value: QueryResult) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null,
  ): Promise<TResult1 | TResult2> {
    return this.execute().then(onfulfilled, onrejected);
  }

  private async execute(): Promise<QueryResult> {
    if (this.executedResult) {
      return this.executedResult;
    }

    switch (this.operation) {
      case 'insert':
        this.executedResult = this.executeInsert();
        break;
      case 'update':
        this.executedResult = this.executeUpdate();
        break;
      case 'delete':
        this.executedResult = this.executeDelete();
        break;
      case 'upsert':
        this.executedResult = this.executeUpsert();
        break;
      case 'select':
      default:
        this.executedResult = this.executeSelect();
        break;
    }

    return this.executedResult;
  }

  private executeSelect(): QueryResult {
    let rows = this.applyFilters(this.db.getMutableRows(this.table)).map((row) => cloneValue(row));
    rows = this.applyOrder(rows);
    rows = this.applyLimit(rows);

    if (this.countRequested && this.headRequested) {
      return {
        data: null,
        error: null,
        count: rows.length,
      };
    }

    const selectedRows = rows.map((row) => this.decorateRow(row));
    return this.finalizeSelection(selectedRows);
  }

  private executeInsert(): QueryResult {
    const tableRows = this.db.getMutableRows(this.table);
    const payloadRows = Array.isArray(this.payload) ? this.payload : [this.payload ?? {}];
    const insertedRows = payloadRows.map((row) => {
      const nextRow = this.prepareInsertedRow(row);
      tableRows.push(nextRow);
      return cloneValue(nextRow);
    });

    if (this.selectColumns === '*' || this.selectColumns.includes('*')) {
      return this.finalizeSelection(insertedRows.map((row) => this.decorateRow(row)));
    }

    return {
      data: null,
      error: null,
    };
  }

  private executeUpsert(): QueryResult {
    const conflictColumn = this.upsertOptions.onConflict;
    const tableRows = this.db.getMutableRows(this.table);
    const payloadRows = Array.isArray(this.payload) ? this.payload : [this.payload ?? {}];
    const affectedRows: Row[] = [];
    const conflictColumns = conflictColumn
      ?.split(',')
      .map((column) => column.trim())
      .filter(Boolean) ?? [];

    for (const payloadRow of payloadRows) {
      if (conflictColumns.length > 0) {
        const existingRow = tableRows.find((row) =>
          conflictColumns.every((column) => valuesEqual(row[column], payloadRow[column])),
        );

        if (existingRow) {
          if (this.upsertOptions.ignoreDuplicates) {
            affectedRows.push(cloneValue(existingRow));
            continue;
          }

          Object.assign(existingRow, cloneValue(payloadRow));
          if ('updated_at' in existingRow) {
            existingRow.updated_at = new Date().toISOString();
          }
          affectedRows.push(cloneValue(existingRow));
          continue;
        }
      }

      const nextRow = this.prepareInsertedRow(payloadRow);
      tableRows.push(nextRow);
      affectedRows.push(cloneValue(nextRow));
    }

    if (this.selectColumns === '*' || this.selectColumns.includes('*')) {
      return this.finalizeSelection(affectedRows.map((row) => this.decorateRow(row)));
    }

    return {
      data: null,
      error: null,
    };
  }

  private executeUpdate(): QueryResult {
    const tableRows = this.db.getMutableRows(this.table);
    const targetRows = this.applyFilters(tableRows);
    const affectedRows: Row[] = [];

    for (const row of targetRows) {
      Object.assign(row, cloneValue((this.payload as Row | null) ?? {}));
      if ('updated_at' in row) {
        row.updated_at = new Date().toISOString();
      }
      affectedRows.push(cloneValue(row));
    }

    if (this.selectColumns === '*' || this.selectColumns.includes('*')) {
      return this.finalizeSelection(affectedRows.map((row) => this.decorateRow(row)));
    }

    return {
      data: null,
      error: null,
    };
  }

  private executeDelete(): QueryResult {
    const tableRows = this.db.getMutableRows(this.table);
    const keptRows = tableRows.filter((row) => !this.matchesFilters(row));
    tableRows.splice(0, tableRows.length, ...keptRows);
    return {
      data: null,
      error: null,
    };
  }

  private finalizeSelection(rows: Row[]): QueryResult {
    if (this.expectMode === 'single') {
      if (rows.length !== 1) {
        return {
          data: null,
          error: new Error(`Expected a single row from ${this.table}, received ${rows.length}`),
        };
      }

      return {
        data: rows[0] ?? null,
        error: null,
      };
    }

    if (this.expectMode === 'maybeSingle') {
      if (rows.length > 1) {
        return {
          data: null,
          error: new Error(`Expected zero or one row from ${this.table}, received ${rows.length}`),
        };
      }

      return {
        data: rows[0] ?? null,
        error: null,
      };
    }

    return {
      data: rows,
      error: null,
      count: this.countRequested ? rows.length : null,
    };
  }

  private prepareInsertedRow(input: Row): Row {
    const nextRow = cloneValue(input);
    if (nextRow.id == null) {
      nextRow.id = this.db.allocateId(this.table);
    }

    const now = new Date().toISOString();
    if (nextRow.created_at == null) {
      nextRow.created_at = now;
    }
    if (nextRow.updated_at == null) {
      nextRow.updated_at = now;
    }

    return nextRow;
  }

  private applyFilters(rows: Row[]): Row[] {
    return rows.filter((row) => this.matchesFilters(row));
  }

  private matchesFilters(row: Row): boolean {
    return this.filters.every((filter) => filter(row));
  }

  private applyOrder(rows: Row[]): Row[] {
    if (!this.orderBy) {
      return rows;
    }

    const ordered = [...rows];
    ordered.sort((left, right) => {
      const leftValue = left[this.orderBy!.column];
      const rightValue = right[this.orderBy!.column];

      if (leftValue == null && rightValue == null) {
        return 0;
      }
      if (leftValue == null) {
        return 1;
      }
      if (rightValue == null) {
        return -1;
      }
      if (leftValue < rightValue) {
        return this.orderBy!.ascending ? -1 : 1;
      }
      if (leftValue > rightValue) {
        return this.orderBy!.ascending ? 1 : -1;
      }
      return 0;
    });

    return ordered;
  }

  private applyLimit(rows: Row[]): Row[] {
    let nextRows = rows;
    if (this.rangeWindow != null) {
      nextRows = nextRows.slice(this.rangeWindow.from, this.rangeWindow.to + 1);
    }
    return this.limitValue == null ? nextRows : nextRows.slice(0, this.limitValue);
  }

  private decorateRow(row: Row): Row {
    const nextRow = cloneValue(row);

    if (this.table === 'join_requests' && this.selectColumns.includes('club:clubs(*)')) {
      nextRow.club = this.db.findById('clubs', row.club_id);
    }

    if (
      this.table === 'leave_requests' &&
      this.selectColumns.includes(
        'membership:memberships!leave_requests_membership_id_fkey(*)',
      )
    ) {
      nextRow.membership = this.db.findById('memberships', row.membership_id);
    }

    return nextRow;
  }

  private buildOrPredicate(clause: string): (row: Row) => boolean {
    const [column, operator, ...rest] = clause.split('.');
    const rawValue = rest.join('.');

    switch (operator) {
      case 'eq':
        return (row) => valuesEqual(row[column ?? ''], rawValue);
      case 'like': {
        const regex = likeToRegExp(rawValue);
        return (row) => regex.test(`${row[column ?? ''] ?? ''}`);
      }
      case 'ilike': {
        const regex = likeToRegExp(rawValue, true);
        return (row) => regex.test(`${row[column ?? ''] ?? ''}`);
      }
      default:
        return () => false;
    }
  }
}
