# Clubline configuration

This directory is the single source of truth for environment-aware project configuration.

## Layout

- `config/environments/backend/`: backend environment templates
- `config/environments/flutter/`: public Flutter runtime defines committed to the repo

## Environment model

Clubline uses these runtime environments:

- `local`: local backend and local-first development workflow
- `dev`: development environment using development Supabase settings
- `prod`: production runtime and production builds

`test` still exists internally for automated backend tests, but it is not a normal operator-facing deployment target.

## Safety rules

- Never commit `.local` backend env files.
- Never put service-role keys or database passwords in Flutter config files.
- Flutter config files may contain only public values such as:
  - `APP_ENV`
  - `API_BASE_URL`
  - `REALTIME_TRANSPORT`
- Backend `.env` files are activated by scripts and copied to `backend/.env` only for local runtime convenience.

## Local workflow

1. Copy the template you need from `config/environments/backend/*.env.example`
2. Create the matching untracked `.local` file in the same folder
3. Activate it with `./scripts/env/use-backend-env.sh <local|dev|prod>`
4. Run Flutter with one of the scripts in `scripts/flutter/`
