# Migrazione Frontend/Backend REST

## Obiettivo

Portare l'app a una struttura chiara:

- `Flutter frontend`: solo UI, stato locale e chiamate HTTP
- `backend server-side`: auth, permessi, validazione e accesso esclusivo a Supabase/DB

## Già migrato

- autenticazione account
- sessione applicativa
- profili giocatore
- info squadra
- permessi vice
- live
- recupero metadata stream
- formazioni
- presenze

Nel frontend questi flussi ora passano dal layer REST:

- [`lib/data/api_client.dart`](/Users/ciro.saraino/clubline/lib/data/api_client.dart)
- [`lib/data/auth_repository.dart`](/Users/ciro.saraino/clubline/lib/data/auth_repository.dart)
- [`lib/data/player_repository.dart`](/Users/ciro.saraino/clubline/lib/data/player_repository.dart)
- [`lib/data/team_info_repository.dart`](/Users/ciro.saraino/clubline/lib/data/team_info_repository.dart)
- [`lib/data/vice_permissions_repository.dart`](/Users/ciro.saraino/clubline/lib/data/vice_permissions_repository.dart)

Il backend dedicato è in:

- [`backend/README.md`](/Users/ciro.saraino/clubline/backend/README.md)

## Stato attuale

La migrazione è completa:

- il frontend Flutter chiama solo API REST
- il backend server-side è l unico punto che parla con Supabase e con il DB
- `Supabase.initialize` è stato rimosso dal client
- i repository Flutter residui usano tutti [`lib/data/api_client.dart`](/Users/ciro.saraino/clubline/lib/data/api_client.dart)

## Config frontend

Il frontend legge il backend da `API_BASE_URL`:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3001/api
```

## Prossimo passo

Il prossimo blocco sensato non è più la migrazione tecnica, ma il rilascio:

- hardening produzione
- variabili ambiente finali
- deploy backend
- build Flutter produzione
