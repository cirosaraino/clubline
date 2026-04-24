# Real Supabase Validation

Questo folder contiene validazioni end-to-end contro un ambiente Supabase reale.

Script disponibile:

- `npm run validate:e2e:supabase`

Prerequisiti minimi:

- backend Clubline avviato in modalita production-like
- `ENABLE_LOCAL_REALTIME_FALLBACK=false`
- `ENABLE_LEGACY_WORKFLOW_FALLBACK=false`
- `backend/.env` configurato con il progetto Supabase reale da validare

Workflow consigliato:

```bash
cp config/environments/backend/prod.env.example config/environments/backend/prod.env.local
./scripts/env/use-backend-env.sh prod
```

Esempio:

```bash
cd backend
BACKEND_BASE_URL=http://127.0.0.1:3101/api npm run validate:e2e:supabase
```

Lo script:

- crea utenti auth reali via backend
- usa token Supabase reali per subscription dirette
- valida auth, RLS, realtime, permessi capitano e isolamento club
- copre anche presenze, trasferimento capitano, cancellazione account e logo storage
- effettua cleanup finale via service role per non lasciare dati sporchi
