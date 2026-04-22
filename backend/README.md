# Clubline Backend

Backend REST TypeScript/Express per autenticazione, flussi multi-club, gestione rosa e permessi capitano/vice.

## Architettura

- `src/routes`: controller HTTP sottili
- `src/validation`: schema Zod centralizzati
- `src/services`: use-case applicativi
- `src/repositories`: accesso dati Supabase
- `src/domain`: tipi e regole condivise
- `src/lib` / `src/middleware`: errori, HTTP helpers, auth e cross-cutting concerns

## Modello giocatore / club

- un giocatore puo esistere senza club
- il legame con un club avviene solo tramite `memberships`
- un giocatore attivo non puo risultare collegato a piu club contemporaneamente
- uscita dal club e svincolo staccano il profilo dalla membership; se il profilo ha un account collegato resta disponibile come identita standalone

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

## Nota sul seed

Il seed di default non crea utenti auth demo: i flussi reali dipendono dagli utenti Supabase del progetto locale. Il file [sql/clubline_seed_dev.sql](/Users/ciro.saraino/clubline/sql/clubline_seed_dev.sql) resta il punto corretto dove aggiungere fixture locali del tuo ambiente.
