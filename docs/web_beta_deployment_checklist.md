# Clubline Web Beta Deployment Checklist

Questa guida prepara un primo beta web pubblico usando:

- frontend web build `dev`
- backend remoto `APP_ENV=dev`
- progetto Supabase `dev`

Obiettivo: testare il percorso reale del prodotto senza usare URL locali, fallback SSE locale o workflow legacy.

## 1. Strategia ambiente

- Flutter web beta:
  - usa `config/environments/flutter/dev.json`
  - sovrascrive `API_BASE_URL` con l URL del backend remoto
  - usa sempre `REALTIME_TRANSPORT=supabase`
- backend remoto beta:
  - `APP_ENV=dev`
  - `NODE_ENV=development`
  - `ENABLE_LOCAL_REALTIME_FALLBACK=false`
  - `ENABLE_LEGACY_WORKFLOW_FALLBACK=false`
- Supabase:
  - progetto `dev`

Nota importante:

- `APP_ENV=dev` con backend remoto e supportato
- `NODE_ENV=production` oggi e consentito solo con `APP_ENV=prod`

## 2. Hosting consigliato

Se usi Render, puoi partire da:

- [render.beta.yaml](/Users/ciro.saraino/clubline/render.beta.yaml)

Servizi previsti:

- `clubline-backend-dev`
- `clubline-web-beta`

## 3. Variabili richieste

### Backend remoto beta

- `APP_ENV=dev`
- `NODE_ENV=development`
- `SUPABASE_URL=https://dlrxhpbgkbzjazhtgumr.supabase.co`
- `SUPABASE_ANON_KEY=<anon key dev>`
- `SUPABASE_SERVICE_ROLE_KEY=<service role key dev>`
- `CORS_ALLOWED_ORIGINS=https://<beta-frontend-origin>`
- `ENABLE_LOCAL_REALTIME_FALLBACK=false`
- `ENABLE_LEGACY_WORKFLOW_FALLBACK=false`

### Frontend web beta

- `APP_ENV=dev`
- `API_BASE_URL=https://<beta-backend-origin>/api`
- `REALTIME_TRANSPORT=supabase`

## 4. Build command frontend

Build locale della web beta:

```bash
API_BASE_URL=https://<beta-backend-origin>/api ./scripts/flutter/build-web-beta.sh
```

Il runner:

- forza `APP_ENV=dev`
- forza `REALTIME_TRANSPORT=supabase`
- rifiuta `API_BASE_URL` locali

## 5. Supabase Auth settings

Nel progetto Supabase `dev` configura:

- `Site URL`: `https://<beta-frontend-origin>/`
- `Redirect URLs`:
  - `https://<beta-frontend-origin>/`
  - opzionale anche i frontend locali che usi ancora in sviluppo:
    - `http://127.0.0.1:4100/`
    - `http://127.0.0.1:4101/`
    - `http://127.0.0.1:4102/`

Clubline oggi usa la root `/` come redirect di:

- registrazione
- recupero password

Non servono callback path custom.

## 6. Realtime readiness

Il beta corretto deve usare Supabase Realtime, non SSE locale.

Checklist:

- `GET /api/auth/public-config` deve rispondere con:
  - `environment.appEnv = "dev"`
  - `realtime.provider = "supabase"`
  - `realtime.localFallbackEnabled = false`
- `POST /api/realtime/session` deve restituire `410 local_realtime_disabled`

## 7. Manual post-deploy tests

### Sanity backend/frontend

1. apri il frontend beta
2. verifica che il login chiami `https://<beta-backend-origin>/api/auth/login`
3. verifica che non compaiano richieste verso `localhost` o `127.0.0.1`

### Auth

1. registra un account nuovo
2. effettua login
3. prova `Password dimenticata?`
4. verifica che il link email riporti alla root del frontend beta

### Club isolation

1. utente A crea un club
2. utente B crea un club diverso
3. verifica che A non veda dati del club di B

### Join / leave / captain

1. utente C richiede ingresso al club di A
2. A approva
3. C richiede uscita
4. A approva o rifiuta
5. verifica permessi captain-only e isolamento dati

### Realtime

1. apri due browser/sessioni diverse
2. da un client invia join request
3. verifica update realtime dashboard capitano
4. approva/rifiuta e verifica update realtime lato richiedente

### Storage / logo

1. crea o modifica club
2. carica logo
3. verifica URL pubblico e refresh UI corretto

## 8. Pre-share gate

Condividi il link beta solo se:

1. `GET /api/health` risponde `ok`
2. `GET /api/auth/public-config` riporta `appEnv=dev`
3. nessuna request del frontend punta a URL locali
4. realtime funziona tra due sessioni reali
5. register/login/reset password funzionano sul dominio beta
6. join/approve/leave funzionano contro Supabase `dev`

## 9. Rischi residui prima della condivisione

- `dev` remoto usa `NODE_ENV=development`, quindi non e identico al runtime `prod`
- se cambi dominio frontend beta devi riallineare subito:
  - `CORS_ALLOWED_ORIGINS`
  - `API_BASE_URL`
  - `Site URL`
  - `Redirect URLs`
- se il backend remoto viene avviato con flag fallback errate, il boot deve fallire; verifica i log del deploy al primo avvio
