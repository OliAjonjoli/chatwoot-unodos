# Uno Dos Cloud fork — `custom/` extensions

**Maintainer / first contributor:** [@OliAjonjoli](https://github.com/OliAjonjoli)

This directory is the Uno Dos Cloud fork's customization layer. It uses Chatwoot's
own extension mechanism (`prepend_mod_with`), the same way `enterprise/` works:

- `custom/` exists → `ChatwootApp.custom?` is true → `ChatwootApp.extensions`
  includes `custom` → `prepend_mod_with('…')` resolves `Custom::…` modules.
- `config/application.rb` adds `custom/app/**` to the eager-load paths and loads
  `custom/config/initializers/**/*.rb` at boot.

## What lives here

| Path | Purpose |
|------|---------|
| `app/controllers/custom/devise_overrides/omniauth_callbacks_controller.rb` | `Custom::DeviseOverrides::OmniauthCallbacksController` — handles the `openid_connect` omniauth callback (provider matching), delegates everything else to `super` (composes with the Enterprise SAML module). |
| `app/builders/custom/oidc_user_builder.rb` | `Custom::OidcUserBuilder` — finds/creates the agent from the OIDC auth hash by email; optional JIT provisioning into a fixed account. |

## Env contract (see also `docs/oidc-sso.md`)

| Env | Effect |
|-----|--------|
| `OPENID_CONNECT_ISSUER` | Set to enable OIDC at all (e.g. `https://sso.unodos.cloud/application/o/chatwoot/`). Unset → fork behaves exactly like stock Chatwoot. |
| `OPENID_CONNECT_CLIENT_ID` / `OPENID_CONNECT_CLIENT_SECRET` | Authentik client credentials. |
| `OPENID_CONNECT_SCOPE` | Default `openid email profile`. |
| `OPENID_CONNECT_JIT_ACCOUNT_ID` | Optional account id for auto-provisioning agents on first login. Unset → strict mode (agent must already exist). |
| `ENABLE_OIDC_LOGIN` | Default `true`; set to `false` to hide the login button while keeping the strategy registered. |

## Upstream merge policy

All Uno Dos Cloud behavior lives in this directory plus a handful of additive core
changes (Gemfile, config/initializers/omniauth.rb, app/models/user.rb,
app/controllers/dashboard_controller.rb, config/application.rb, the v3 login page).
Keep this diff as-is on every upstream merge: it is intentionally small and env-gated.
