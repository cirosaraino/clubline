# Clubline

Piattaforma multi-club costruita su Flutter + backend REST TypeScript/Express, con Supabase usato solo lato server per auth, storage e accesso dati.

## Struttura

- `lib/`: app Flutter web/mobile
- `backend/`: API REST, auth, permessi, service layer e accesso a Supabase
- `sql/`: schema e migrazioni DB
- `scripts/`: script operativi per build, env e bootstrap database
- `docs/`: note architetturali e guide di rilascio

## Avvio rapido

1. Prepara l env backend partendo da uno dei template in `backend/`.
2. Attiva l env desiderato:
   - `./scripts/env/use-backend-env.sh dev`
   - `./scripts/env/use-backend-env.sh prod`
3. Avvia il backend:
   - `cd backend && npm install && npm run dev`
4. Avvia Flutter puntando al backend locale:
   - `flutter run --dart-define=API_BASE_URL=http://localhost:3001/api`

## Database Supabase

Per bootstrap e verifica dei nuovi progetti `clubline-dev` e `clubline-prod` usa:

- `./scripts/db/apply-clubline-schema.sh dev`
- `./scripts/db/apply-clubline-schema.sh prod`
- `./scripts/db/verify-clubline-schema.sh dev`
- `./scripts/db/verify-clubline-schema.sh prod`

I dettagli operativi sono in [docs/production_release_guide.md](/Users/ciro.saraino/clubline/docs/production_release_guide.md).
