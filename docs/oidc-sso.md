# Chatwoot OIDC SSO (Authentik) — fork runbook

Uno Dos Cloud fork of `chatwoot/chatwoot` with an **env-gated OpenID Connect strategy**
for agent SSO via Authentik (mode B, the same pattern as Frappe/Zammad/Leads).

- **Fork:** this repo — branch `unodos/oidc`, based on upstream tag (currently `v4.16.2`)
- **Image:** `ghcr.io/<owner>/<repo>:v<upstream>-oidc.<run>` (built by `build-image.yml`)
- **Related:** `unodos.cloud/docs/platform/frappe-sso.md` (SAML path, premium-gated — superseded by OIDC), `unodos.cloud/chat/README.md` (deployment)

---

## 1. What this adds (and what it does not)

| Capability | Status |
|---|---|
| Agent SSO via OIDC (Authentik, code flow) | ✅ this fork |
| JIT provisioning of agents (optional, fixed account) | ✅ this fork (`OPENID_CONNECT_JIT_ACCOUNT_ID`) |
| SAML SSO | ⛔ unchanged upstream behavior — premium-gated, do **not** enable |
| Google OAuth | ✅ unchanged (stock) |
| Password login | ✅ unchanged — always available |

When `OPENID_CONNECT_ISSUER` is **unset**, the image behaves exactly like stock
Chatwoot (all fork logic is env-gated). One image serves both modes, which is also
your rollback path (flip env, not image).

### Auth flow

```text
Agent → /app/login → "Continue with SSO (Authentik)" → /omniauth/openid_connect (GET)
  → Authentik authorize (M365 login, group policy) → code callback
  → /omniauth/openid_connect/callback → 307 → /auth/openid_connect/callback
  → Custom::DeviseOverrides::OmniauthCallbacksController#omniauth_success
  → Custom::OidcUserBuilder (match by email; JIT-create if configured)
  → sign_in_user → /app/login?email=…&sso_auth_token=… → session established
```

The fork hooks Chatwoot's own extension mechanism (`prepend_mod_with` + the `custom/`
dir) — the same way `enterprise/` adds SAML — so upstream merges stay trivial.

> **Why the GET is allowed:** OmniAuth 2.x defaults `allowed_request_methods` to
> `[:post]`, which would reject the login button's plain GET link (404 via Devise
> passthru). `custom/config/initializers/oidc.rb` re-enables GET when OIDC is on —
> the same pattern Chatwoot's enterprise SAML flow relies on. The strategy still
> validates `state`/`nonce` in the session before exchanging the code.

## 2. Environment contract

Set these on the `rails`/`sidekiq` services (compose `environment:` or `.env`):

| Env | Required | Effect |
|---|---|---|
| `OPENID_CONNECT_ISSUER` | to enable | `https://sso.unodos.cloud/application/o/chatwoot/` (Authentik per-app issuer; discovery must work at `…/.well-known/openid-configuration`) |
| `OPENID_CONNECT_CLIENT_ID` | yes | Authentik OIDC client id (confidential) |
| `OPENID_CONNECT_CLIENT_SECRET` | yes | Authentik OIDC client secret |
| `OPENID_CONNECT_SCOPE` | no | default `openid email profile` |
| `OPENID_CONNECT_JIT_ACCOUNT_ID` | no | account id for auto-provisioning agents on first login (`2` for `Uno Dos Cloud`). Unset → strict mode: agent must already exist (Settings → Agents) |
| `ENABLE_OIDC_LOGIN` | no | default `true`; `false` hides the login button while keeping the strategy registered |

The login page shows the Authentik button only when `OPENID_CONNECT_ISSUER` is set and
`ENABLE_OIDC_LOGIN != false` (`allowed_login_methods` in `DashboardController`).

## 3. Authentik setup (one-time)

Create via the Admin UI or the documented REST-API pattern (`frappe-sso.md` §8):

1. **Provider — OIDC** (confidential client):
   - Client type: **confidential**
   - **Grant types: `authorization_code`, `refresh_token`** ⚠️ — Authentik (2026.x) defaults
     `grant_types` to empty; without this the authorize endpoint answers
     `invalid_request` / "Invalid grant_type for provider". Set it via the API:
     `PATCH /api/v3/providers/oauth2/<pk> -d '{"grant_types": ["authorization_code", "refresh_token"]}'`
   - Redirect URIs (strict): `https://chat.unodos.cloud/omniauth/openid_connect/callback`
   - Signing key: reuse the shared provider signing key (`e265bc97-…`) if it must
     interop; otherwise the default is fine
   - Scopes: `openid`, `email`, `profile` (built-ins)
2. **Application** — e.g. `chatwoot` OIDC app, launch URL `https://chat.unodos.cloud`,
   policy binding to group **`emp-all`** (all staff, same as ERP) — or a dedicated
   `app-chatwoot` group if you want to gate more narrowly.
3. Export `client_id`/`client_secret` to the password manager; put them in the
   deployment `.env` (chmod 600, never commit).

> The existing **SAML** provider `Chatwoot SAML` / app `chatwoot` (Task 14 stub) can
> stay untouched; it is inert. Do **not** enable the `saml` account feature.

## 4. Enable on the deployment

```bash
cd /opt/appdata/unodos.cloud/chat
# in .env (rails+sidekiq share it):
#   OPENID_CONNECT_ISSUER=https://sso.unodos.cloud/application/o/chatwoot/
#   OPENID_CONNECT_CLIENT_ID=…
#   OPENID_CONNECT_CLIENT_SECRET=…
#   OPENID_CONNECT_JIT_ACCOUNT_ID=2        # optional: auto-provision agents
docker compose -f docker-compose.chatwoot.yml up -d
```

## 5. Verification (staging / test run)

1. **Login page** shows "Continue with SSO (Authentik)" (GET `/app/login` contains the button).
2. Click it → you land on `sso.unodos.cloud` → Microsoft login.
3. Callback → agent dashboard. The user is matched **by email**.
4. Negative checks:
   - Agent **not** in the Authentik group → policy deny before reaching Chatwoot.
   - Unknown email + JIT **off** → `/app/login?error=oidc-authentication-failed`.
   - Disabled M365 user → no session.
5. Password login for `ops@unodos.cloud` still works.
6. Confirm SAML is untouched (login page has no SAML button; `account.feature_enabled?('saml')` still false).

```bash
# quick strategy check on a live stack
docker compose -f docker-compose.chatwoot.yml exec rails \
  bundle exec rails runner 'puts OmniAuth.config.path_prefix; puts Rails.application.middleware.map { |m| m.klass }.include?(OmniAuth::Builder)'
```

## 6. Upgrade procedure (every upstream release)

The automation does the plumbing; you do the review + deploy:

1. `sync-upstream.yml` opens a PR merging the newest `v*` tag into `unodos/oidc`.
2. **Review the PR:** read the upstream release notes (migrations? breaking changes?),
   confirm the fork diff is still the one isolated commit.
3. Merge → `build-image.yml` publishes `v<tag>-oidc.<run>` to GHCR.
4. Deploy (backup first — always):
   ```bash
   /opt/appdata/unodos.cloud/chat/scripts/backup-chatwoot.sh
   cd /opt/appdata/unodos.cloud/chat
   docker compose -f docker-compose.chatwoot.yml pull
   docker compose -f docker-compose.chatwoot.yml up -d
   docker compose -f docker-compose.chatwoot.yml exec rails bundle exec rails db:chatwoot_prepare
   ```
5. Verify per §5, plus a smoke conversation + SLA rule still applies.

Manual alternative (no GitHub yet): build on the host —

```bash
cd /opt/appdata/unodos.cloud/chat/fork
git fetch upstream --tags
git merge --no-edit upstream/v<new-tag>
docker build -f docker/Dockerfile -t ghcr.io/<owner>/<repo>:v<new-tag>-oidc.<n> .
```

## 7. Rollback

- **Env flip (preferred):** unset `OPENID_CONNECT_ISSUER`, restart → stock behavior
  (button hidden, strategy not registered). No image change.
- **Image:** point compose back at the previous `v<tag>-oidc.<n>` tag and `up -d`.
- ⚠️ Chatwoot DB migrations are **forward-only** — if `db:chatwoot_prepare` already ran
  on the new version, an image downgrade alone can break. Restore the `pg_dump` from
  step 4 if you must return to a pre-migration state.

## 8. Known limits / follow-ups

- **Mobile deep link** (`sign_in_user_on_mobile`) still targets `auth/saml`; mobile SSO
  is out of scope until an agent uses the mobile app.
- **JIT role mapping** (groups → roles) is not implemented; JIT agents get role `agent`.
  Extend `Custom::OidcUserBuilder` if you need it.
- **Upstream OIDC** is on Chatwoot's roadmap (#11288/#12541). When it lands, this patch
  can likely be dropped — track it before each merge.
- Full E2E with the real Authentik/M365 identity is the one manual step in the pipeline.

## 9. Debug notes (from go-live)

- **Authentik `invalid_request` / "Invalid grant_type for provider"** on authorize →
  the provider's `grant_types` was empty; PATCH it to `["authorization_code", "refresh_token"]`.
- **500 `ActionDispatch::Cookies::CookieOverflow`** on the callback → DeviseTokenAuth's
  `redirect_callbacks` stashes the whole auth hash in the cookie session (OIDC auth hash
  ~8KB > 4KB). The fork's `Custom::DeviseOverrides::OmniauthCallbacksController#redirect_callbacks`
  bypasses the stash for `openid_connect`, mirroring the Enterprise SAML module.
