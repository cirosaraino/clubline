# PRD - Intervento logo + performance iPhone

## Problema originale (utente)
"bisogna cambiare il logo dell'app utilizzando lo stesso logo che abbiamo per lo stemma, inoltre quando apro l'app da cellulare in particolare da iphone quest'ultima è lentissima, le schermate di salvataggio e/o login non si chiudono i salvataggi restano appesi, bisogna fare un controllo generale su questo"

## Decisioni architetturali
- Evitata dipendenza rigida da `localhost` per la base API: la web app ora usa automaticamente `origin/api` se `API_BASE_URL` non è impostata.
- Aggiunto timeout globale alle chiamate HTTP frontend per evitare attese infinite e modali bloccate.
- Ridotta la dipendenza dal refresh sincrono nei flussi critici (login/salvataggio): refresh in background con coda anti-concorrenza.
- Uniformato il logo app alle asset dello stemma tramite rigenerazione icone web/PWA, Android e iOS.

## Implementato
- **Logo app allineato allo stemma**:
  - aggiornate icone PWA/web (`favicon`, `Icon-192/512`, `maskable`)
  - aggiornate icone Android launcher (`mipmap-*`)
  - aggiornate icone iOS (`AppIcon.appiconset`)
- **Migliorata stabilità iPhone/login/salvataggi**:
  - timeout API a 15s + messaggi errore rete chiari
  - login/registrazione/password non attendono più refresh completo per chiudere il foglio
  - salvataggi Team Info / Permessi Vice / Profilo giocatore non restano bloccati in attesa di refresh
  - `AppSessionController` con guardia anti-refresh concorrenti + coda refresh
- **Controllo generale**:
  - rivisto flusso modali e refresh globali per eliminare doppie chiamate pesanti immediate

## Backlog prioritizzato
### P0
- Validazione manuale su iPhone reale (Safari + app aggiunta in Home): login, salvataggio info squadra, salvataggio permessi vice, salvataggio giocatore.

### P1
- Aggiungere telemetria leggera lato client (durata richiesta, endpoint, timeout count) per individuare eventuali endpoint backend lenti.
- Ridurre eventuali payload nelle chiamate di refresh globale se emergono latenze lato rete mobile.

### P2
- Introduzione di caching locale per dati statici (team info/permessi) con invalidazione su update.

## Prossimi task consigliati
1. Test E2E su iPhone in rete mobile reale.
2. Se rimane lentezza, profilare endpoint backend più lenti e introdurre ottimizzazione mirata server-side.

---

## Aggiornamento successivo - Code quality report `iphone-slowness`

### Richiesta
Applicare i fix suggeriti dal report che segnalava assenza file Python in `/app/backend`.

### Interventi effettuati
- Aggiunta configurazione dedicata: `/app/lintiq.config.yaml`
  - backend impostato correttamente su `/app/backend/src`
  - analisi TypeScript/Dart abilitate
  - analisi Python disabilitata per questo progetto
- Aggiunta configurazione alternativa `.lintiq.yml` (stesso mapping) per compatibilità con naming diversi del tool.
- Aggiunto script di verifica target analisi: `/app/scripts/verify_analysis_targets.sh`.
- Aggiornata documentazione backend (`/app/backend/README.md`) con sezione esplicita su path e linguaggio reali.
- Aggiornato `README.md` root con nota di struttura (backend TypeScript, non Python).

---

## Aggiornamento successivo - Realtime globale (richiesta: aggiornamento istantaneo rosa e tutta l'app)

### Richiesta
Aggiornare in tempo reale, senza refresh manuale, quando un altro utente crea/modifica contenuti (in particolare giocatori nella sezione Rosa).

### Interventi effettuati
- **Backend realtime via SSE**
  - aggiunto bus eventi in memoria: `backend/src/lib/realtime-events.ts`
  - aggiunto endpoint stream: `GET /api/realtime/events` in `backend/src/routes/realtime.routes.ts`
  - routing attivato in `backend/src/routes/index.ts`
- **Pubblicazione eventi su tutte le mutazioni**
  - players, lineups, attendance, streams, team-info, vice-permissions ora emettono eventi realtime dopo le scritture.
- **Frontend realtime globale e silenzioso**
  - aggiunto bridge realtime web con `EventSource` (`lib/core/realtime/*`)
  - aggiunto host globale `AppRealtimeSyncHost` che converte eventi backend in `AppDataSync.notifyDataChanged(...)`
  - integrazione globale in `lib/app.dart`
- **Comportamento UX**
  - aggiornamento automatico senza toast/notifiche visive (come richiesto)
  - approccio bilanciato performance: connessione persistente + heartbeat + reconnessione leggera
  - aggiunta **coda anti-rimbalzo** lato client: finestra 300ms, merge scope e ultimo reason
  - soglia dinamica adattiva: passa a 600ms se arrivano >=4 eventi in 1s; torna a 300ms dopo 3s di traffico basso

### Verifica tecnica
- Backend TypeScript compilato con successo (`npm run typecheck` e `npm run build`).

---

## Aggiornamento successivo - "fixa tutto" (audit completo)

### Interventi applicati
- **Sicurezza realtime**
  - endpoint SSE `GET /api/realtime/events` ora richiede token valido (`token` query param) e verifica sessione.
  - centralizzata la risoluzione utente da token in middleware auth (`resolvePrincipalFromToken`) per riuso.
- **Riduzione storm su presenze**
  - rimossa sincronizzazione doppia lato client in `AttendancePage` (niente chiamata esplicita `/weeks/:id/sync` prima del fetch entries).
  - rimosso broadcast realtime dall'endpoint manuale `/attendance/weeks/:id/sync` per evitare cascata eventi non necessaria.
- **Anti-rimbalzo fetch pagine**
  - introdotta coda reload con coalescing e refresh silenzioso in:
    - `PlayersPage`
    - `StreamsPage`
    - `LineupsPage`
    - `AttendancePage`
    - `AttendanceArchivePage`
  - eliminato effetto spinner full-page aggressivo durante refresh realtime quando i dati sono già presenti.
- **Realtime client più robusto**
  - `AppRealtimeSyncHost` ora apre stream solo con sessione valida letta da `AuthSessionStore`.
  - riconnessione più rapida (4s) e gestione login/logout più consistente.
- **Performance API mobile**
  - `ApiClient` con retry leggero per GET (2 tentativi, delay 250ms) in caso di timeout/errori rete transienti.
- **Ottimizzazione backend query giocatori**
  - filtri `id_console`, `nome`, `cognome`, `q` spostati a livello query Supabase per ridurre payload e lavoro in memoria.

### Verifica tecnica aggiuntiva
- Backend ricompilato con successo dopo i fix (`npm run typecheck`, `npm run build`).
