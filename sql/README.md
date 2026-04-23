# Clubline SQL Layout

La root `sql/` contiene solo gli script attivi del percorso schema Clubline.

Ordine di applicazione supportato:

1. `production_schema.sql`
2. `clubline_multi_club_refactor.sql`
3. `clubline_player_identity_refactor.sql`
4. `clubline_player_membership_guardrails.sql`
5. `clubline_backend_hardening.sql`
6. `clubline_post_refactor_grants.sql`

Script attivi aggiuntivi:

- `clubline_player_identity_refactor_verify.sql`
- `clubline_seed_dev.sql`

Gli script storici non piu attivi sono stati spostati sotto `sql/deprecated/`.
Non devono essere rieseguiti nei progetti Supabase attuali.
