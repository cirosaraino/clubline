# Clubline Backend

Backend REST TypeScript/Express per autenticazione, flussi multi-club, gestione rosa e permessi capitano/vice.

## Architettura

- `src/routes`: controller HTTP sottili
- `src/validation`: schema Zod centralizzati
- `src/services`: use-case applicativi e adapter verso RPC SQL critiche
- `src/repositories`: accesso dati Supabase
- `src/domain`: tipi e regole condivise
- `src/lib` / `src/middleware`: errori, HTTP helpers, auth e cross-cutting concerns
- `sql/clubline_backend_hardening.sql`: vincoli, RLS, audit trail, publication realtime e RPC transazionali
- `sql/README.md`: elenco del solo percorso schema attivo; gli script storici sono stati spostati in `sql/deprecated/`

## Modello giocatore / club

- un giocatore puo esistere senza club
- il legame con un club avviene solo tramite `memberships`
- un giocatore attivo non puo risultare collegato a piu club contemporaneamente
- uscita dal club e svincolo staccano il profilo dalla membership; se il profilo ha un account collegato resta disponibile come identita standalone

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

## Variabili ambiente

Template disponibili:

- [`.env.example`](/Users/ciro.saraino/clubline/backend/.env.example)
- [`.env.clubline-dev.example`](/Users/ciro.saraino/clubline/backend/.env.clubline-dev.example)
- [`.env.clubline-test.example`](/Users/ciro.saraino/clubline/backend/.env.clubline-test.example)
- [`.env.clubline-prod.example`](/Users/ciro.saraino/clubline/backend/.env.clubline-prod.example)

Variabili runtime richieste:

- `PORT`
- `NODE_ENV`
- `CORS_ORIGIN`
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

- `development`: abilita i fallback solo in modo esplicito se stai facendo debugging locale controllato
- `test`: il fallback workflow legacy resta disponibile per l harness locale, ma non va usato come comportamento applicativo normale
- `production`: il fallback workflow legacy e vietato; il processo fallisce all avvio se viene abilitato e i flussi club devono usare solo `RPC SQL`

## Run From Zero

1. Installa dipendenze backend

```bash
./scripts/backend/install.sh
```

2. Crea il file locale ambiente

```bash
cp backend/.env.clubline-dev.example backend/.env.clubline-dev.local
./scripts/env/use-backend-env.sh dev
```

3. Applica schema e guardrail

```bash
./scripts/backend/migrate.sh dev
./scripts/db/verify-clubline-schema.sh dev
```

4. Seed opzionale dev/test

```bash
./scripts/backend/seed.sh dev
```

5. Avvia il server

```bash
./scripts/backend/dev.sh
```

## Script principali

- `./scripts/backend/install.sh`: install dipendenze backend
- `./scripts/backend/dev.sh [target]`: seleziona env e avvia il server in watch
- `./scripts/backend/migrate.sh <dev|test|prod>`: applica schema completo
- `./scripts/backend/seed.sh <dev|test>`: esegue il seed hook locale
- `./scripts/backend/reset-dev-db.sh <dev|test>`: rebuild schema + seed + verify
- `./scripts/backend/rebuild-from-zero.sh <dev|test>`: install + env + reset completo + typecheck

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

## Nota sul seed

Il seed di default non crea utenti auth demo: i flussi reali dipendono dagli utenti Supabase del progetto locale. Il file [sql/clubline_seed_dev.sql](/Users/ciro.saraino/clubline/sql/clubline_seed_dev.sql) resta il punto corretto dove aggiungere fixture locali del tuo ambiente.

## Checklist Supabase produzione

- applica anche [sql/clubline_backend_hardening.sql](/Users/ciro.saraino/clubline/sql/clubline_backend_hardening.sql)
- verifica `RLS`, `policies`, `functions` e publication realtime con [scripts/db/verify-clubline-schema.sh](/Users/ciro.saraino/clubline/scripts/db/verify-clubline-schema.sh)
- usa il backend REST o Edge Functions con service role per le mutazioni critiche
- usa select/subscription dirette solo dove le policy RLS sono sufficienti e i payload restano club-scoped
