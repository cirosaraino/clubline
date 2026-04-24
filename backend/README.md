# Clubline Backend

Backend REST TypeScript/Express per autenticazione, flussi multi-club, gestione rosa e permessi capitano/vice.

## Architettura

- `src/routes`: controller HTTP sottili
- `src/validation`: schema Zod centralizzati
- `src/services`: use-case applicativi e adapter verso RPC SQL critiche
- `src/repositories`: accesso dati Supabase
- `src/domain`: tipi e regole condivise
- `src/lib` / `src/middleware`: errori, HTTP helpers, auth e cross-cutting concerns
- `../config/environments/backend`: template ambiente versionati
- `sql/clubline_backend_hardening.sql`: vincoli, RLS, audit trail, publication realtime e RPC transazionali
- `sql/README.md`: elenco del solo percorso schema attivo; gli script storici sono stati spostati in `sql/deprecated/`

## Modello giocatore / club

- un giocatore puo esistere senza club
- il legame con un club avviene solo tramite `memberships`
- un giocatore attivo non puo risultare collegato a piu club contemporaneamente
- uscita dal club e svincolo staccano il profilo dalla membership; se il profilo ha un account collegato resta disponibile come identita standalone

## Naming legacy mantenuto per compatibilita

La codebase applicativa usa ormai il lessico `club`, ma alcuni nomi restano legacy nel database o nei payload compatibili:

- `team_settings` / `team_permission_settings`: tabelle legacy del vecchio bootstrap singleton, mantenute solo per compatibilita con il percorso SQL storico e con il refactor multi-club
- `team_role`: colonna legacy di `player_profiles`, ancora attiva nello schema per evitare una migration dati ad alto impatto
- `vice_manage_team_info`: flag DB legacy ancora mappato nel codice come permesso `club info`
- `/team-info` e `teamInfo`: alias compatibili che puntano al nuovo blocco `club-info`

Regola pratica:

- nei nuovi moduli applicativi usa sempre `club`
- i nomi `team_*` vanno toccati solo dentro migration DB pianificate e con backfill esplicito

## Sicurezza e consistenza

- mutazioni critiche club/join/leave/captain sono pensate come `RPC-only` con funzioni SQL `security definer`
- il backend REST usa queste RPC come percorso primario; il fallback CRUD legacy va tenuto solo per sviluppo/test controllato
- gli accessi diretti client-side alle tabelle core devono essere `read-only` e protetti da RLS
- i vincoli SQL restano l ultima linea di difesa contro doppie membership, doppio capitano, richieste pendenti duplicate e stati incoerenti

## Realtime

- in produzione il canale corretto e `Supabase Realtime` sulle tabelle core (`clubs`, `memberships`, `join_requests`, `leave_requests`, `player_profiles`, `club_settings`, `club_permission_settings`, `club_membership_events`)
- il client Flutter si collega direttamente a `Supabase Realtime` usando il token Supabase gia restituito dal backend auth
- le subscription client devono essere filtrate per `club_id`, `auth_user_id`, `requester_user_id` o `player_id`, mai broad su tutto il dataset
- il bus SSE in-memory del backend resta solo come fallback locale / sviluppo e va usato esplicitamente con `REALTIME_TRANSPORT=local`

## Configurazione ambienti

Template versionati:

- [`.env.example`](/Users/ciro.saraino/clubline/backend/.env.example)
- [`../config/environments/backend/local.env.example`](/Users/ciro.saraino/clubline/config/environments/backend/local.env.example)
- [`../config/environments/backend/dev.env.example`](/Users/ciro.saraino/clubline/config/environments/backend/dev.env.example)
- [`../config/environments/backend/prod.env.example`](/Users/ciro.saraino/clubline/config/environments/backend/prod.env.example)
- [`../config/environments/backend/test.env.example`](/Users/ciro.saraino/clubline/config/environments/backend/test.env.example)

File locali non versionati attesi:

- `config/environments/backend/local.env.local`
- `config/environments/backend/dev.env.local`
- `config/environments/backend/prod.env.local`

Attivazione:

```bash
./scripts/env/use-backend-env.sh local
./scripts/env/use-backend-env.sh dev
./scripts/env/use-backend-env.sh prod
```

Lo script copia il file scelto in `backend/.env`, che resta il solo file letto da `dotenv` in runtime locale.

Variabili runtime richieste:

- `APP_ENV`
- `PORT`
- `NODE_ENV`
- `CORS_ALLOWED_ORIGINS`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Variabili opzionali:

- `SUPABASE_PROJECT_NAME`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_DB_URL`
- `ENABLE_LOCAL_REALTIME_FALLBACK`
- `ENABLE_LEGACY_WORKFLOW_FALLBACK`

Regola consigliata:

- `APP_ENV=local`: sviluppo locale e fallback realtime locale opzionale
- `APP_ENV=dev`: backend locale ma con configurazione sviluppo / progetto Supabase di dev
- `APP_ENV=prod`: runtime di produzione, senza fallback realtime locale o workflow legacy
- `NODE_ENV=test`: riservato ai test backend

## Run From Zero

1. Installa dipendenze backend

```bash
./scripts/backend/install.sh
```

2. Crea il file locale ambiente

```bash
cp config/environments/backend/local.env.example config/environments/backend/local.env.local
./scripts/env/use-backend-env.sh local
```

3. Applica schema e guardrail

```bash
./scripts/backend/migrate.sh local
./scripts/db/verify-clubline-schema.sh local
```

4. Seed opzionale local/dev/test

```bash
./scripts/backend/seed.sh local
```

5. Avvia il server

```bash
./scripts/backend/dev.sh local
```

## Script principali

- `./scripts/backend/install.sh`: install dipendenze backend
- `./scripts/backend/dev.sh [target]`: seleziona env e avvia il server in watch
- `./scripts/backend/migrate.sh <local|dev|prod|test>`: applica schema completo
- `./scripts/backend/seed.sh <local|dev|test>`: esegue il seed hook locale
- `./scripts/backend/reset-dev-db.sh <local|dev|test>`: rebuild schema + seed + verify
- `./scripts/backend/rebuild-from-zero.sh <local|dev|test>`: install + env + reset completo + typecheck

## Verifica rapida

```bash
cd backend
npm run check
```

## Validazione E2E reale su Supabase

Per validare il percorso production-like contro un progetto Supabase reale:

```bash
cd backend
BACKEND_BASE_URL=http://127.0.0.1:3101/api npm run validate:e2e:supabase
```

Uso consigliato:

- avvia il backend con `ENABLE_LOCAL_REALTIME_FALLBACK=false`
- avvia il backend con `ENABLE_LEGACY_WORKFLOW_FALLBACK=false`
- usa un `.env` puntato al progetto Supabase reale che vuoi verificare
- lascia allo script il cleanup finale dei dati creati per il test

## Render / deploy

In produzione usa:

- `APP_ENV=prod`
- `NODE_ENV=production`
- `CORS_ALLOWED_ORIGINS=<origini pubbliche consentite>`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Il fallback workflow legacy e il fallback realtime locale devono restare spenti.

## Nota sul seed

Il seed di default non crea utenti auth demo: i flussi reali dipendono dagli utenti Supabase del progetto locale. Il file [sql/clubline_seed_dev.sql](/Users/ciro.saraino/clubline/sql/clubline_seed_dev.sql) resta il punto corretto dove aggiungere fixture locali del tuo ambiente.

## Checklist Supabase produzione

- applica anche [sql/clubline_backend_hardening.sql](/Users/ciro.saraino/clubline/sql/clubline_backend_hardening.sql)
- verifica `RLS`, `policies`, `functions` e publication realtime con [scripts/db/verify-clubline-schema.sh](/Users/ciro.saraino/clubline/scripts/db/verify-clubline-schema.sh)
- usa il backend REST o Edge Functions con service role per le mutazioni critiche
- usa select/subscription dirette solo dove le policy RLS sono sufficienti e i payload restano club-scoped
