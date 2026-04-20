# Clubline Backend

Backend REST TypeScript/Express che governa auth, permessi, validazioni e accesso a Supabase per tutta la piattaforma Clubline.

## Variabili ambiente

Template disponibili:

- [`.env.example`](/Users/ciro.saraino/clubline/backend/.env.example)
- [`.env.clubline-dev.example`](/Users/ciro.saraino/clubline/backend/.env.clubline-dev.example)
- [`.env.clubline-prod.example`](/Users/ciro.saraino/clubline/backend/.env.clubline-prod.example)

Variabili runtime:

- `PORT`
- `NODE_ENV`
- `CORS_ORIGIN`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Variabile opzionale per gli script SQL:

- `SUPABASE_DB_URL`

## Comandi

```bash
npm install
npm run dev
npm run typecheck
npm run test
```

## Switch env locale

```bash
./scripts/env/use-backend-env.sh dev
./scripts/env/use-backend-env.sh prod
```

## Bootstrap database

```bash
./scripts/db/apply-clubline-schema.sh dev
./scripts/db/apply-clubline-schema.sh prod
./scripts/db/verify-clubline-schema.sh dev
./scripts/db/verify-clubline-schema.sh prod
```

## Nota architetturale

Il frontend Flutter non parla direttamente con Supabase o con il database. Tutta la logica di sicurezza, isolamento multi-club e autorizzazione passa da questo backend.
