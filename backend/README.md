# Squadra Backend

Backend REST separato per l'app Flutter. Questo servizio parla con Supabase e con il database
al posto del frontend. Il client Flutter dovra chiamare solo queste API.

## Stack

- TypeScript
- Express
- Supabase JS

## Variabili ambiente

Copiale da [`.env.example`](./.env.example).

- `PORT`: porta del server
- `NODE_ENV`: ambiente
- `CORS_ORIGIN`: origini abilitate
- `SUPABASE_URL`: URL del progetto Supabase
- `SUPABASE_ANON_KEY`: chiave anon per auth
- `SUPABASE_SERVICE_ROLE_KEY`: chiave service role per accesso al DB

## Comandi

```bash
npm install
npm run dev
```

Avvio frontend Flutter puntando al backend locale:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3001/api
```

Build produzione:

```bash
npm run build
npm start
```

## Risposte JSON

Formato scelto per restare semplice e stabile:

- `auth login/register/refresh`:
  ```json
  {
    "session": {
      "accessToken": "...",
      "refreshToken": "...",
      "expiresAt": "2026-04-13T12:00:00.000Z",
      "user": {
        "id": "...",
        "email": "..."
      }
    }
  }
  ```
- `auth me`:
  ```json
  {
    "user": {
      "id": "...",
      "email": "..."
    }
  }
  ```
- `players list`:
  ```json
  {
    "players": []
  }
  ```
- `create/update/claim`:
  ```json
  {
    "player": {}
  }
  ```
- `team-info`:
  ```json
  {
    "teamInfo": {}
  }
  ```
- `vice-permissions`:
  ```json
  {
    "permissions": {}
  }
  ```
- `streams list`:
  ```json
  {
    "streams": []
  }
  ```
- `streams create/update`:
  ```json
  {
    "stream": {}
  }
  ```
- `stream metadata`:
  ```json
  {
    "metadata": {}
  }
  ```
- `lineups list`:
  ```json
  {
    "lineups": []
  }
  ```
- `lineup players / assignments`:
  ```json
  {
    "assignments": []
  }
  ```
- `attendance active week`:
  ```json
  {
    "week": {}
  }
  ```
- `attendance archived weeks`:
  ```json
  {
    "weeks": []
  }
  ```
- `attendance entries`:
  ```json
  {
    "entries": []
  }
  ```
- `attendance lineup filters`:
  ```json
  {
    "filters": {
      "absentPlayerIds": [],
      "pendingPlayerIds": []
    }
  }
  ```
- errors:
  ```json
  {
    "error": {
      "message": "..."
    }
  }
  ```

## Permessi

- `captain`: accesso completo
- `vice_captain`: accesso solo se abilitato dalle `team_permission_settings`
- `player`: accesso limitato

## Nota architetturale

Il frontend Flutter non deve parlare direttamente con Supabase o col database. Questa cartella `backend/`
e il layer unico che governa auth, permessi e CRUD.

## Stato migrazione

La separazione è completa:

- auth
- players
- team-info
- vice-permissions
- streams
- stream metadata
- lineups
- attendance

Il frontend Flutter non usa più Supabase direttamente.
