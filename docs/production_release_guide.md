# Rilascio Produzione

Questa guida usa una produzione pulita:

- database nuovo su Supabase
- backend REST su Render
- frontend Flutter Web su Render Static Site

L'app in produzione deve parlare solo col backend REST. Il frontend non deve mai usare Supabase direttamente.

## 1. Crea un progetto Supabase nuovo

Non ripulire il database di sviluppo. Crea un progetto dedicato alla produzione da zero.

1. Apri `database.new` oppure la dashboard Supabase.
2. Crea il progetto produzione.
3. Attendi che il database sia pronto.
4. Vai in `Settings -> API`.
5. Conserva:
   - `Project URL`
   - `anon/public key`
   - `service_role/secret key`

## 2. Inizializza il database prod

1. Vai in `SQL Editor`.
2. Crea una nuova query.
3. Incolla tutto il contenuto di [production_schema.sql](/Users/ciro.saraino/squadra_app/sql/production_schema.sql).
4. Esegui la query.

Questo file crea il database finale di produzione gia pulito, con:

- giocatori
- info squadra
- permessi vice
- live
- formazioni
- presenze

In piu blocca l accesso diretto client-side al database: in produzione deve parlare col DB solo il backend tramite `service_role`.

## 3. Prepara il repository per Render

Render deploya da GitHub, GitLab o Bitbucket.

1. Crea un repository remoto se ancora non esiste.
2. Carica tutto il progetto.
3. Verifica che nel repository siano presenti:
   - [render.yaml](/Users/ciro.saraino/squadra_app/render.yaml)
   - [render-build-web.sh](/Users/ciro.saraino/squadra_app/scripts/render-build-web.sh)

## 4. Deploy del backend

Nel dashboard Render:

1. `New -> Blueprint`
2. collega il repository
3. scegli il branch corretto
4. conferma il file `render.yaml`
5. completa le variabili ambiente del servizio `squadra-backend`

Il backend usa TypeScript anche in fase di build, quindi il blueprint installa anche le `devDependencies` durante il deploy.

Valori da inserire:

- `NODE_ENV=production`
- `SUPABASE_URL=<Project URL Supabase produzione>`
- `SUPABASE_ANON_KEY=<anon key Supabase produzione>`
- `SUPABASE_SERVICE_ROLE_KEY=<service role key Supabase produzione>`
- `CORS_ORIGIN=https://squadra-web.onrender.com`

Il valore di `CORS_ORIGIN` si aggiorna appena conosci l'URL reale del frontend.

Quando il deploy finisce, Render assegna al backend un URL tipo:

- `https://squadra-backend.onrender.com`

Controllo rapido:

- apri `https://squadra-backend.onrender.com/api/health`
- deve rispondere con uno stato `ok`

## 5. Deploy del frontend

Sempre da Blueprint Render verra creato anche il servizio `squadra-web`.

Per il sito statico non impostare manualmente un `plan` nel blueprint: Render lo gestisce come static site.

Variabile da inserire:

- `API_BASE_URL=https://squadra-backend.onrender.com/api`

Il build usa [render-build-web.sh](/Users/ciro.saraino/squadra_app/scripts/render-build-web.sh), che:

- recupera Flutter se non e disponibile
- esegue `flutter pub get`
- compila la web app in release

Quando il deploy finisce, Render assegna al frontend un URL tipo:

- `https://squadra-web.onrender.com`

Questo sara il primo URL pubblico della tua app.

## 6. Chiudi il collegamento frontend/backend

Dopo che conosci l'URL reale del frontend:

1. apri il servizio `squadra-backend` su Render
2. aggiorna `CORS_ORIGIN` con l'URL reale del frontend
3. salva e fai redeploy del backend

Esempio:

- `CORS_ORIGIN=https://squadra-web.onrender.com`

Se in futuro aggiungi un dominio personalizzato, usa quello al posto dell'URL `onrender.com`.

## 7. Verifica finale pre-go-live

Test da fare sul link frontend produzione:

1. registrazione nuovo account
2. login
3. completamento profilo
4. modifica info squadra
5. creazione live
6. creazione formazione
7. creazione settimana presenze
8. voto presenze da giocatore
9. apertura da mobile e comparsa invito installazione
10. installazione icona sulla schermata Home

## 7.bis Recupero password

Per far funzionare il recupero password via email devi configurare anche Supabase Auth:

1. apri il progetto Supabase produzione
2. vai in `Authentication -> URL Configuration`
3. imposta `Site URL` con l URL reale del frontend
4. aggiungi nei `Redirect URLs` almeno l URL pubblico del frontend

Esempio:

- `https://squadra-web.onrender.com`
- `https://squadra-web.onrender.com/`

Se in futuro userai un dominio personalizzato, aggiungi anche quello.

## 8. URL produzione

Finche non aggiungi un dominio personalizzato, l'URL di produzione della web app sara:

- l'URL del servizio `squadra-web` in Render

Quello del backend sara:

- l'URL del servizio `squadra-backend` in Render, con suffisso `/api`

Esempio finale:

- frontend: `https://squadra-web.onrender.com`
- backend API: `https://squadra-backend.onrender.com/api`

## 9. Dominio personalizzato opzionale

Se vuoi un URL piu pulito, aggiungi un dominio personalizzato al servizio frontend Render e poi aggiorna:

- `CORS_ORIGIN` nel backend
- eventuali link pubblici condivisi

Per la prima pubblicazione puoi tranquillamente partire dagli URL `onrender.com`.
