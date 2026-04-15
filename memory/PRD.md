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

---

## Aggiornamento successivo - Fix realtime iPhone Home Screen (PWA standalone)

### Problema segnalato
- In Safari Home Screen su iPhone il realtime non partiva oppure riprendeva solo dopo refresh manuale.

### Fix applicati
- **Bridge SSE web più robusto** (`lib/core/realtime/app_realtime_bridge_web.dart`):
  - evitata riapertura continua della connessione durante stato `connecting` (finestra di stabilizzazione 10s)
  - reconnessione forzata quando il canale entra in stato `closed`
  - gestione migliore di `readyState` per evitare stream “bloccati”
- **Host realtime lifecycle-aware** (`lib/ui/widgets/app_realtime_sync_host.dart`):
  - observer lifecycle app aggiunto
  - su `resumed` viene forzata reconnessione completa
  - su `paused/inactive/detached` il canale viene chiuso pulitamente
  - watchdog periodic reconnection mantenuto per massima affidabilità

### Obiettivo UX
- Aggiornamenti istantanei affidabili anche in modalità app Home Screen iOS, senza refresh manuale.

---

## Aggiornamento successivo - Fix bootstrap accesso (falso "disconnesso" all'avvio)

### Problema segnalato
- All'apertura app compariva stato non autenticato; cliccando "Accedi" la sessione risultava già valida in background.

### Fix applicati
- `AppShellPage` ora mostra **overlay iniziale "Verifica accesso in corso..."** sulla Home durante bootstrap sessione.
- Timeout overlay impostato a **1.5s** (come richiesto).
- Apertura login/signup bloccata quando:
  - sessione è ancora in caricamento, oppure
  - sessione è già autenticata (**mai aprire login se già loggato**, come richiesto).

### Risultato atteso
- Niente più effetto “finto disconnesso” nei primi istanti.
- Niente apertura inutile della pagina di accesso quando sei già autenticato.

### Miglioria UX successiva
- Transizione ingresso resa più “native” tra overlay bootstrap e Home:
  - durata **420ms**
  - effetto **fade + slide-up delicata**
  - curva **easeOutCubic**

### Fix anti-flicker successivo
- Gestione a due fasi overlay bootstrap in `AppShellPage`:
  - fase 1: "Verifica accesso in corso..." (1.5s)
  - fase 2: mini overlay "Sincronizzazione profilo..." con guardia minima 1s
- Priorità zero flicker: l'utente non vede più il riquadro "Accedi" nel passaggio tra verifica e sessione valida.
- Migliorato refresh sessione: dopo `restoreSession()` viene notificato subito lo stato auth, riducendo il gap visivo prima del rendering corretto.

### Rifinitura premium successiva
- Overlay dinamico negli ultimi 300ms della fase di guardia:
  - testo finale: **"Accesso confermato"**
  - mostrato solo quando la sessione risulta autenticata
  - fallback: resta "Sincronizzazione profilo..." se auth non ancora confermata

### Correzione successiva (regressione click login/registrazione)
- Ripristinata la piena cliccabilità di **Accedi/Registrati** per utenti realmente non autenticati.
- Il mini-overlay di sincronizzazione post-verifica ora si mostra solo quando la sessione è già autenticata (evita blocchi inutili in stato guest).
- Rimossa la barriera logica che bloccava l'apertura del foglio auth quando `session.isLoading` era ancora true ma l'utente non era loggato.

### Correzione definitiva blocco pulsanti Home
- Sistemato il layer overlay: viene montato solo quando davvero visibile.
- In stato guest (non loggato) senza overlay attivo, non c'è più nessun layer trasparente a intercettare i tap.
- Risolto il caso in cui i pulsanti Home risultavano visivamente presenti ma non cliccabili.

### Audit approfondito successivo (touch/login Home + lifecycle)
- Controllati i layer touch globali e relativi widget (`AppShellPage`, `MobileWebInstallPromptHost`, Home card accesso).
- Root cause residua trovata: overlay Home ancora impostato con logica di blocco non condizionata al solo stato autenticato.
- Fix applicato:
  - blocco touch overlay attivo **solo** quando `session.isAuthenticated == true`
  - in stato guest overlay eventualmente visibile ma **non** intercetta tap (`IgnorePointer` non bloccante)
- Esito atteso: `Accedi` / `Registrati` sempre cliccabili quando non loggato.

### Fix aggiuntivo post-test agent
- Ridotto rumore/errori guest su bootstrap sessione:
  - in `AppSession.refresh()` i permessi vice non vengono più richiesti quando utente non autenticato.
  - evita chiamata guest a `/api/vice-permissions` con 401 in console durante il caricamento Home.
- Aggiornato `/app/memory/test_credentials.md` per allineamento con report di test.

### Test automatico anti-regressione aggiunto
- Creato `integration_test/guest_home_buttons_clickable_test.dart` con 2 scenari E2E:
  1. `guest-home-buttons-clickable-browser`
  2. `guest-home-buttons-clickable-standalone-simulated`
- Verifica automatica: da utente guest i pulsanti **Accedi** e **Registrati** sono cliccabili e aprono correttamente il foglio auth.
- Aggiunta dipendenza `integration_test` in `pubspec.yaml`.
- Aggiunto supporto simulazione standalone web per E2E (`e2e_force_standalone` / `e2e_standalone=1`) in `mobile_web_install_bridge_web.dart`.

---

## Aggiornamento successivo - Home riorganizzata con menu profilo in AppBar

### Richiesta utente
- Icona profilo in alto a destra (stile app moderne) con azioni account centralizzate.
- Voci richieste nel menu:
  - Cambia password
  - Esci
  - Modifica profilo giocatore (se profilo esiste)
  - Completa Profilo giocatore (se profilo non esiste)
  - Solo capitano: Gestione permessi vice

### Implementazione
- Aggiunta icona profilo con `PopupMenuButton` nell’`AppBar` della Home (solo utente autenticato).
- Regole menu implementate puntualmente:
  - `currentUser != null` → **Modifica profilo giocatore**
  - `currentUser == null` → **Completa Profilo giocatore**
  - sempre presenti: **Cambia password**, **Esci**
  - solo `isCaptain == true`: **Gestione permessi vice**
- Aggiunto flusso edit profilo corrente in `AppShellPage` (`_openEditCurrentProfile`).
- Pulizia Home per maggiore ordine:
  - rimosse azioni account duplicate dalla card centrale (ora guidano al menu profilo)
  - rimossa card permessi vice dalla Home per ridurre rumore visivo

### Hardening anti-regressione
- Aggiunti `Key` stabili su pulsanti guest e voci menu profilo per test automation robusta.

### Refinement UX successivo (nuovo accesso)
- Su richiesta utente, quando `needsProfileSetup == true` è stato aggiunto in Home (dentro card accesso/profilo) il bottone evidente:
  - **Completa Profilo giocatore**
- Obiettivo: rendere il percorso più intuitivo al primo accesso senza obbligare subito all'uso del menu profilo.

### Micro-animazione CTA (one-shot)
- Applicata al bottone **Completa Profilo giocatore** una pulse leggera di **900ms**.
- Trigger: **solo una volta assoluta per dispositivo** (persistenza via `SharedPreferences`).
- Dopo la prima visualizzazione, il bottone resta statico (niente animazioni ripetute).

---

## Aggiornamento successivo - Selettore orario formazioni stile iPhone

### Richiesta utente
- Dopo scelta giorno, rendere la scelta orario più intuitiva come sveglia iPhone, con ruote ore/minuti.
- Formato 24h, minuti liberi (00-59), valido sia in creazione che modifica.

### Implementazione
- In `AddLineupPage` sostituito `showTimePicker` con picker a ruote (`CupertinoDatePickerMode.time`) dentro bottom sheet.
- Configurazione applicata:
  - **24h** (`use24hFormat: true`)
  - **minuteInterval: 1** (ogni minuto)
  - CTA chiare: **Annulla** / **Conferma**
- Il flusso vale automaticamente sia per **nuova formazione** che **modifica formazione**.

---

## Aggiornamento successivo - Fix recupero metadata live (YouTube/Twitch)

### Problema segnalato
- Su "Recupera dati dal link" con YouTube compariva errore tecnico: `edge function returned a non-2xx status code`.

### Intervento backend (robusto, senza regressioni)
- `StreamMetadataService` reso resiliente:
  - gestione nativa YouTube (estrazione videoId + lookup oEmbed)
  - fallback automatico YouTube/Twitch anche se provider esterno o edge function fallisce
  - niente propagazione raw dell'errore edge all'utente
- Per Twitch mantenuta logica dedicata; in caso di errore rete/API viene usato fallback sicuro (live o video).

### Intervento frontend (UX fallback manuale)
- In `StreamFormPage` se il recupero automatico fallisce:
  - messaggio chiaro e non tecnico
  - precompilazione minima assistita (`status`, `playedOn`, `provider` stimato)
  - utente può completare manualmente il titolo e salvare (fallback confermabile)

### Outcome
- YouTube non si blocca più con errore edge non-2xx esposto in UI.
- Twitch resta supportato con degrado controllato e logica pulita.

---

## Aggiornamento successivo - Presenze: filtri capitano + riepilogo verde

### Richiesta finale confermata
- Rimosso filtro "in attesa" (non desiderato).
- Aggiunto filtro **solo capitano**, collassabile (default chiuso), con 3 campi separati:
  - nome
  - cognome
  - id console
- Riepilogo in alto verde quando tutti hanno risposto nel periodo selezionato.

### Implementazione
- In `AttendancePage`:
  - nuovo pannello `_CaptainAttendanceFiltersCard` visibile **solo** se `viewer.isCaptain == true`
  - filtri applicati alle card giocatore (`AttendancePlayerEntries`) per nome/cognome/id console
  - stato collapse persistente in pagina con default chiuso
  - stato vuoto dedicato quando i filtri non trovano risultati
- In `AttendanceHeroCard`:
  - tinta verde card + badge **Completato** quando `pendingCount == 0` su tutti i giorni del periodo

### Hardening anti-regressione
- Aggiunte key stabili per automation:
  - `attendance-captain-filters-card`
  - `attendance-captain-filter-nome-input`
  - `attendance-captain-filter-cognome-input`
  - `attendance-captain-filter-console-id-input`
  - `attendance-captain-filters-clear-button`
  - `attendance-captain-filters-clear-button`

### Refinement richiesto successivo (colorazione riepilogo)
- Ripristinato il blocco hero presenze come prima (rimosso verde/completato in alto).
- Nuova logica colore applicata **solo ai tab giorno-per-giorno**:
  - `Risposte X/Y`: **giallo di default**, **verde solo** quando `X == Y`
  - `Sì`: sempre verde
  - `No`: sempre rosso
  - `Attesa`: sempre giallo

### Ritocchi UI successivi richiesti
- Rinominata la sezione filtri capitano in: **"Filtro presenza giocatore"**.
- In sezione **"Chi manca ancora"** rimosso il testo "Mostra/Nascondi dettagli":
  - lasciata solo la freccia come controllo di apertura/chiusura dropdown.

---

## Aggiornamento successivo - Formazioni: eliminazione totale + raggruppamento per giornata

### Richiesta
- Pulsante eliminazione totale formazioni (solo utenti con permesso gestione formazioni: capitano + vice abilitato).
- Raggruppamento formazioni per giornata con dropdown collassabili.
- Stato iniziale: aperto solo giorno corrente; se il giorno corrente non esiste, tutti chiusi.

### Implementazione backend
- Nuovo endpoint: `DELETE /api/lineups/all` (auth required).
- Logica service: cancella tutte le formazioni e relative assegnazioni (`lineup_players`) con controllo permessi.
- Route order sicuro: `/all` definita prima di `/:id` per evitare shadowing.

### Implementazione frontend
- `LineupRepository.deleteAllLineups()` aggiunto.
- In `LineupsPage`:
  - nuovo pulsante AppBar `delete_sweep` con dialog conferma semplice
  - feedback loading/snackbar e sync realtime dopo eliminazione totale
  - grouping per giorno con card `_LineupsDayGroupCard` collassabili
  - default collapses all e apre solo il giorno corrente se presente; altrimenti tutti chiusi

### Hardening
- Test hooks aggiunti:
  - `lineups-delete-all-button`
  - `lineups-day-group-toggle-<dayKey>`

### Refinement successivo richiesto (Formazioni per giorno)
- Aggiunta cancellazione per singola giornata nel dropdown:
  - icona cestino sempre visibile
  - descrizione non visibile in UI: ora è solo **tooltip** su hover/tap-hold con testo **"Elimina tutte le formazioni del giorno"**
  - conferma semplice prima dell’eliminazione
- Implementato endpoint dedicato per delete batch per giornata:
  - `DELETE /api/lineups/day` con `lineup_ids[]`
- Migliorato messaggio stato utente in card formazione:
  - da "Sei in formazione" a **"Sei in formazione come <RUOLO>"** (es. COC)

### Correzione post-validazione geometria campo
- Corretto orientamento sinistra/destra per centrali e mediani in `lineup_pitch_view.dart`:
  - `CCS` e `CDCS` spostati verso sinistra
  - `CCD` e `CDCD` spostati verso destra
- Mantiene invariata la logica verticale richiesta:
  - `CDCS/CDCD` più arretrati
  - `COC` più avanzato

### Refinement UI successivo (compattazione sezioni)
- Compattate con livello medio le due sezioni in alto su gestione formazione:
  1. Banner stato utente (incluso/non incluso)
  2. Card "Disponibilità filtrate"
- Ridotti padding, gap verticali, dimensioni icona e raggio bordi per migliorare densità visiva mantenendo leggibilità.

### Refinement successivo (coerenza header)
- Reso più uniforme l’header meta della schermata gestione formazione:
  - modulo e data/ora ora sono allineati nello stesso blocco `Wrap` con pill consistenti
  - introdotta icona modulo per coerenza visiva con data/ora
  - ridotti ulteriormente gap verticali per look più compatto e ordinato

### Refinement successivo (priorità campo + anti-accavallamento ruoli)
- In `lineup_pitch_view.dart` introdotto solver di layout riga (`_resolveRowLefts`) per evitare sovrapposizioni tra slot ruolo.
- Separazione ruoli resa più robusta su tutti i moduli:
  - offset orizzontali calibrati (larghi/centrali)
  - separazione minima orizzontale per riga
  - fallback di compressione controllata quando lo spazio disponibile è limitato
- Corretto il calcolo span interno del solver (coordinate di partenza) per preservare separazione e offset desiderati senza comprimere prematuramente.
- In `lineup_players_page.dart` compattato ulteriormente l’header (meta/formazione) per dare più spazio utile al campo.

### Hotfix compilazione Web
- Corretto errore di compile-time in `attendance_overview_cards.dart`:
  - `AppCountPill` del badge "Completato" non può essere `const` con colore tema runtime.
  - Rimosso `const` dal widget specifico mantenendo invariata la UI.

---

## Aggiornamento successivo - Schermata Rosa: filtri collapsable + recap macroruoli

### Richiesta
- Filtri apribili/chiudibili con default chiuso.
- Recap in alto del totale giocatori per macroruolo (solo ruolo principale), sempre sul totale squadra.

### Implementazione
- Aggiunta card recap in alto con:
  - totale giocatori squadra
  - 4 pillole conteggio: Portiere, Difensore, Centrocampista, Attaccante
- Filtri trasformati in sezione collapsable:
  - header "Filtri rosa" con chevron apri/chiudi
  - default **chiusi**
  - stato visibile `visibili/totali` mantenuto in header
  - messaggio compatto quando filtri attivi ma pannello chiuso

### Ritocco successivo richiesto
- Rimossi i numeri dalle intestazioni delle sezioni ruolo nella terza sezione della schermata Rosa (PORTIERI, DIFENSORI, ecc.), mantenendo invariati i conteggi nello schema recap in alto.
