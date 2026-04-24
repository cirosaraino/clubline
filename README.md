# Clubline

Piattaforma multi-club costruita su Flutter + backend REST TypeScript/Express, con Supabase usato solo lato server per auth, storage e accesso dati.

## Struttura progetto

- `lib/`: app Flutter
  - `bootstrap/`: bootstrap e fail-fast startup
  - `core/`: config, sessione, realtime, theme e cross-cutting concerns
  - `data/`: repository e client REST
  - `models/`: modelli di dominio condivisi dal frontend
  - `ui/`: pagine e widget condivisi
- `backend/`: API REST TypeScript/Express
  - `src/config`: configurazione tipizzata e validazione startup
  - `src/routes`: entrypoint HTTP sottili
  - `src/services`: use-case applicativi
  - `src/repositories`: accesso dati Supabase / RPC
  - `src/validation`: schema Zod centralizzati
  - `src/middleware`, `src/lib`: cross-cutting concern
- `config/`: sorgente unica della configurazione per ambiente
  - `config/environments/backend/`: template env backend
  - `config/environments/flutter/`: runtime defines Flutter pubblici
- `sql/`: schema attivo, hardening e verification path
- `scripts/`: automazione locale/build/deploy
- `docs/`: guide operative e note architetturali

## Ambienti supportati

- `local`: sviluppo locale completo
- `dev`: backend locale configurato sul progetto Supabase di sviluppo
- `prod`: build e runtime di produzione

`test` resta un target interno per automation e harness backend, non per uso operativo quotidiano.

## Setup rapido

1. Installa dipendenze backend

```bash
./scripts/backend/install.sh
```

2. Crea il file env backend desiderato partendo dal template corretto

```bash
cp config/environments/backend/local.env.example config/environments/backend/local.env.local
cp config/environments/backend/dev.env.example config/environments/backend/dev.env.local
cp config/environments/backend/prod.env.example config/environments/backend/prod.env.local
```

3. Attiva il profilo backend che vuoi usare

```bash
./scripts/env/use-backend-env.sh local
```

4. Avvia backend e frontend

```bash
./scripts/backend/dev.sh
./scripts/flutter/run-local.sh
```

## Comandi per ambiente

### Locale

```bash
./scripts/env/use-backend-env.sh local
./scripts/backend/dev.sh local
./scripts/db/apply-clubline-schema.sh local
./scripts/db/verify-clubline-schema.sh local
./scripts/flutter/run-local.sh
```

### Development

```bash
./scripts/env/use-backend-env.sh dev
./scripts/backend/dev.sh dev
./scripts/db/apply-clubline-schema.sh dev
./scripts/db/verify-clubline-schema.sh dev
./scripts/flutter/run-dev.sh
./scripts/flutter/build-web-dev.sh
```

### Production

```bash
./scripts/env/use-backend-env.sh prod
./scripts/db/apply-clubline-schema.sh prod
./scripts/db/verify-clubline-schema.sh prod
./scripts/flutter/build-web-prod.sh
./scripts/flutter/build-android-prod.sh
./scripts/flutter/build-ios-prod.sh
```

## Strategia di configurazione

- Il backend legge sempre `backend/.env`, ma i file sorgente per ambiente stanno in `config/environments/backend/`.
- Lo script `./scripts/env/use-backend-env.sh <target>` copia il file `.local` scelto in `backend/.env`.
- Flutter usa `--dart-define-from-file=config/environments/flutter/<env>.json`.
- Nessun file sorgente va modificato a mano per cambiare ambiente.
- Le chiavi service-role non esistono mai nei define Flutter.
- Se la configurazione è invalida, backend e frontend falliscono all avvio in modo esplicito.

## File sicuri da committare

- `config/environments/backend/*.env.example`
- `config/environments/flutter/*.json`
- `backend/.env.example`

## File che devono restare privati

- `config/environments/backend/*.env.local`
- `backend/.env`
- qualunque file con service role key, DB password o secret operativi

## Database Supabase

Per bootstrap, hardening e verifica degli ambienti usa:

- `./scripts/db/apply-clubline-schema.sh local`
- `./scripts/db/apply-clubline-schema.sh dev`
- `./scripts/db/apply-clubline-schema.sh prod`
- `./scripts/db/verify-clubline-schema.sh local`
- `./scripts/db/verify-clubline-schema.sh dev`
- `./scripts/db/verify-clubline-schema.sh prod`

I dettagli operativi sono in:

- [config/README.md](/Users/ciro.saraino/clubline/config/README.md)
- [backend/README.md](/Users/ciro.saraino/clubline/backend/README.md)
- [docs/production_release_guide.md](/Users/ciro.saraino/clubline/docs/production_release_guide.md)
