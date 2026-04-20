# Clubline Dev/Prod Guide

Questa guida copre i due progetti Supabase dedicati:

- `clubline-dev`: ambiente di sviluppo e test
- `clubline-prod`: ambiente di produzione

## 1. File env da preparare

Template già inclusi nel repository:

- [backend/.env.example](/Users/ciro.saraino/clubline/backend/.env.example)
- [backend/.env.clubline-dev.example](/Users/ciro.saraino/clubline/backend/.env.clubline-dev.example)
- [backend/.env.clubline-prod.example](/Users/ciro.saraino/clubline/backend/.env.clubline-prod.example)

Crea i file locali non versionati:

- `backend/.env.clubline-dev.local`
- `backend/.env.clubline-prod.local`

Campi da valorizzare:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

`SUPABASE_DB_URL` serve solo agli script SQL ed è la connection string Postgres del progetto Supabase.

## 2. Attiva l env backend corretto

```bash
./scripts/env/use-backend-env.sh dev
./scripts/env/use-backend-env.sh prod
```

Lo script copia il file locale scelto in `backend/.env`.

## 3. Bootstrap database

Per applicare schema base + refactor multi-club:

```bash
./scripts/db/apply-clubline-schema.sh dev
./scripts/db/apply-clubline-schema.sh prod
```

Per verificare che il database sia pronto:

```bash
./scripts/db/verify-clubline-schema.sh dev
./scripts/db/verify-clubline-schema.sh prod
```

Gli script applicano:

- [sql/production_schema.sql](/Users/ciro.saraino/clubline/sql/production_schema.sql)
- [sql/clubline_multi_club_refactor.sql](/Users/ciro.saraino/clubline/sql/clubline_multi_club_refactor.sql)

La migrazione multi-club ora evita di creare un club legacy artificiale su un database nuovo e vuoto.

## 4. Collegamento GitHub

Remote previsto:

```bash
git remote set-url origin https://github.com/cirosaraino/clubline.git
```

Se il repository finale sarà sotto un owner diverso, sostituisci l URL con quello corretto.

## 5. Deploy Render

Il blueprint aggiornato è [render.yaml](/Users/ciro.saraino/clubline/render.yaml) e crea:

- `clubline-backend`
- `clubline-web`

Variabili backend Render:

- `NODE_ENV=production`
- `SUPABASE_URL=<clubline-prod url>`
- `SUPABASE_ANON_KEY=<clubline-prod anon key>`
- `SUPABASE_SERVICE_ROLE_KEY=<clubline-prod service role key>`
- `CORS_ORIGIN=https://clubline-web.onrender.com`

Variabile frontend Render:

- `API_BASE_URL=https://clubline-backend.onrender.com/api`

## 6. Checklist prima del go-live

1. `npm run typecheck` in `backend/`
2. `npm run test` in `backend/`
3. `flutter analyze --no-fatal-infos`
4. `flutter test`
5. verifica register/login/email verification
6. verifica create club / join / leave / approve flows
7. verifica upload logo e colori derivati
8. verifica isolamento dati tra club
