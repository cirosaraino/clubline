# Legacy Single-Team Modules

Questi moduli appartengono al vecchio assetto pre-multi-club e includono assunzioni non piu valide:

- tabelle singleton (`team_settings`, `team_permission_settings`)
- policy RLS dev aperte (`USING (true)` / `WITH CHECK (true)`)
- flussi precedenti al modello `club + memberships + requests`

Sono stati archiviati qui per evitare che vengano confusi con il percorso schema attivo.
Non riutilizzarli come base per nuove migration.
