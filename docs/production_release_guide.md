# Clubline Dev/Prod Guide

Questa guida copre il rilascio con i tre profili runtime del progetto:

- `local`
- `dev`
- `prod`

## 1. File env da preparare

Template versionati:

- [backend/.env.example](/Users/ciro.saraino/clubline/backend/.env.example)
- [config/environments/backend/local.env.example](/Users/ciro.saraino/clubline/config/environments/backend/local.env.example)
- [config/environments/backend/dev.env.example](/Users/ciro.saraino/clubline/config/environments/backend/dev.env.example)
- [config/environments/backend/prod.env.example](/Users/ciro.saraino/clubline/config/environments/backend/prod.env.example)

Crea i file locali non versionati:

- `config/environments/backend/local.env.local`
- `config/environments/backend/dev.env.local`
- `config/environments/backend/prod.env.local`

Campi da valorizzare:

- `APP_ENV`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

`SUPABASE_DB_URL` serve solo agli script SQL ed è la connection string Postgres del progetto Supabase.

## 2. Attiva l env backend corretto

```bash
./scripts/env/use-backend-env.sh local
./scripts/env/use-backend-env.sh dev
./scripts/env/use-backend-env.sh prod
```

Lo script copia il file locale scelto in `backend/.env`.

## 3. Bootstrap database

Per applicare schema base + refactor multi-club:

```bash
./scripts/db/apply-clubline-schema.sh local
./scripts/db/apply-clubline-schema.sh dev
./scripts/db/apply-clubline-schema.sh prod
```

Per verificare che il database sia pronto:

```bash
./scripts/db/verify-clubline-schema.sh local
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

- `APP_ENV=prod`
- `NODE_ENV=production`
- `SUPABASE_URL=<clubline-prod url>`
- `SUPABASE_ANON_KEY=<clubline-prod anon key>`
- `SUPABASE_SERVICE_ROLE_KEY=<clubline-prod service role key>`
- `CORS_ALLOWED_ORIGINS=https://clubline-web.onrender.com`

Variabile frontend Render:

- `API_BASE_URL=https://clubline-backend.onrender.com/api`
- `APP_ENV=prod`

## 6. Comandi Flutter

```bash
./scripts/flutter/run-local.sh
./scripts/flutter/run-dev.sh
./scripts/flutter/build-web-dev.sh
./scripts/flutter/build-web-beta.sh
./scripts/flutter/build-web-prod.sh
./scripts/flutter/build-android-prod.sh
./scripts/flutter/build-ios-prod.sh
```

Se vuoi produrre una build web `dev` destinata a un backend dev remoto, passa esplicitamente l URL del backend:

```bash
API_BASE_URL=https://clubline-backend-dev.example.com/api ./scripts/flutter/build-web-dev.sh
```

Il file `config/environments/flutter/dev.json` resta intenzionalmente orientato al workflow standard `backend locale + Supabase dev`.

Per il primo beta web con backend remoto `dev`, usa invece:

```bash
API_BASE_URL=https://<beta-backend-origin>/api ./scripts/flutter/build-web-beta.sh
```

La checklist completa e in [docs/web_beta_deployment_checklist.md](/Users/ciro.saraino/clubline/docs/web_beta_deployment_checklist.md).

## 7. Supabase Auth redirect URLs

Clubline usa l origin corrente della web app come `redirectTo` per:

- registrazione
- recupero password

Quindi in Supabase Auth devi configurare, per ogni ambiente, la root del frontend realmente usato.

Redirect URLs minimi consigliati:

- local:
  - `http://127.0.0.1:4100/`
  - `http://127.0.0.1:4101/`
  - `http://127.0.0.1:4102/`
  - opzionali anche le varianti `localhost`
- dev:
  - se lavori solo in locale contro Supabase dev, usa gli stessi URL locali
  - se esiste un frontend dev pubblico, aggiungi anche la sua origin root
- prod:
  - `https://clubline-web.onrender.com/`

Valori da allineare in Supabase:

- `Site URL`: origin principale dell ambiente
- `Redirect URLs`: tutte le root autorizzate

Il progetto oggi si aspetta il ritorno alla root `/` del frontend, non a callback path dedicate.

## 8. Checklist prima del go-live

1. `npm run typecheck` in `backend/`
2. `npm run test` in `backend/`
3. `flutter analyze --no-fatal-infos`
4. `flutter test`
5. verifica register/login/email verification
6. verifica create club / join / leave / approve flows
7. verifica upload logo e colori derivati
8. verifica isolamento dati tra club
