# Chatwoot · Uno Dos Cloud fork

**Fork of [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot)** with **env-gated OpenID Connect (OIDC) agent SSO** for [Authentik](https://goauthentik.io/) and other standard OIDC providers.

| | |
|--|--|
| **Upstream** | [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) (MIT) |
| **Default branch** | `unodos/oidc` (based on upstream `v4.16.2` + continuous sync) |
| **Maintainer / first contributor** | [**@OliAjonjoli**](https://github.com/OliAjonjoli) — Uno Dos Cloud |
| **OIDC runbook** | [`docs/oidc-sso.md`](./docs/oidc-sso.md) |
| **Custom layer** | [`custom/`](./custom/) |

> When OIDC env vars are **unset**, this image behaves exactly like stock Chatwoot. One image, two modes — flip env to enable or roll back SSO without changing the image.

---

## Fork enhancements (Uno Dos Cloud)

These are the **individual changes** on top of upstream Chatwoot. Everything below this section is stock Chatwoot documentation.

### 1. Agent SSO via OpenID Connect (Authentik)

Upstream Chatwoot ships Google OAuth and **premium-gated SAML** only. This fork adds a full **OIDC authorization-code** strategy for agents:

- Login button: **Continue with SSO (Authentik)** on `/app/login`
- OmniAuth strategy `openid_connect` (code flow + discovery)
- Callback handled in `Custom::DeviseOverrides::OmniauthCallbacksController`
- Users matched **by email** (case-insensitive), consistent with the rest of the Uno Dos Cloud platform

| Env | Purpose |
|-----|---------|
| `OPENID_CONNECT_ISSUER` | Enable OIDC (Authentik per-app issuer URL) |
| `OPENID_CONNECT_CLIENT_ID` / `OPENID_CONNECT_CLIENT_SECRET` | Confidential client credentials |
| `OPENID_CONNECT_SCOPE` | Default `openid email profile` |
| `ENABLE_OIDC_LOGIN` | Hide the button without unregistering the strategy (`false`) |

### 2. Optional JIT agent provisioning

| Env | Purpose |
|-----|---------|
| `OPENID_CONNECT_JIT_ACCOUNT_ID` | Auto-create agents into this Chatwoot account on first SSO login |

- **Set** → unknown emails are created as agents in that account  
- **Unset** → strict mode: the agent must already exist (Settings → Agents)

Implemented in `Custom::OidcUserBuilder` (`custom/app/builders/`).

### 3. Production hardening (Authentik + OmniAuth 2.x)

Fixes discovered while integrating Authentik in production:

| Issue | Fix |
|-------|-----|
| Login button GET → 404 (OmniAuth 2 defaults to POST only) | Allow GET when OIDC is on (`custom/config/initializers/oidc.rb`) |
| `CookieOverflow` on callback (OIDC auth hash ~8KB) | Bypass DeviseTokenAuth session-stash 307 for `openid_connect` (handle callback in-request) |
| `?error=no-account-found` after successful IdP login | Compare `auth_hash['provider']` with `.to_s` — OmniAuth may store a Symbol; stock signup path was wrongly hit when signup is disabled |
| Authentik `invalid_request` / empty grant types | Documented: provider needs `authorization_code` (+ `refresh_token`) |

### 4. Upstream-friendly layout

Fork logic lives almost entirely under **`custom/`**, using Chatwoot’s own `prepend_mod_with` extension mechanism (same pattern as `enterprise/`):

- Small additive core touch points only (Gemfile, `omniauth.rb`, `User` omniauth providers, login page, dashboard allowed methods)
- Env-gated so merges from upstream stay simple
- CI workflows: `build-image` (GHCR tags) + `sync-upstream` (PR when new `v*` tags appear)

### 5. Docs

- **[`docs/oidc-sso.md`](./docs/oidc-sso.md)** — full runbook (env contract, Authentik setup, verify, upgrade, rollback, debug notes)
- **[`custom/README.md`](./custom/README.md)** — what lives in the custom layer

### Quick start (OIDC)

```bash
# .env (rails + sidekiq)
OPENID_CONNECT_ISSUER=https://sso.example.com/application/o/chatwoot/
OPENID_CONNECT_CLIENT_ID=…
OPENID_CONNECT_CLIENT_SECRET=…
OPENID_CONNECT_JIT_ACCOUNT_ID=2   # optional
ENABLE_OIDC_LOGIN=true
```

Authentik redirect URI (strict):

```text
https://<your-chatwoot-host>/omniauth/openid_connect/callback
```

See [`docs/oidc-sso.md`](./docs/oidc-sso.md) for the complete checklist.

### Contributors (this fork)

| Contributor | Role |
|-------------|------|
| [**@OliAjonjoli**](https://github.com/OliAjonjoli) | Creator & first contributor — OIDC SSO fork, Authentik integration, production hardening |

Upstream Chatwoot has hundreds of contributors; see [chatwoot.com/docs/contributors](https://www.chatwoot.com/docs/contributors).

---

## Branching (this fork)

| Branch | Purpose |
|--------|---------|
| `unodos/oidc` | **Default** — upstream release tag + OIDC commits |
| upstream `develop` / `master` / `v*` | Synced via `sync-upstream` workflow when new tags ship |

---

# Upstream Chatwoot

The modern customer support platform, an open-source alternative to Intercom, Zendesk, Salesforce Service Cloud etc.

> The badges and screenshots below refer to **upstream** [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot).

<p>
  <img src="https://img.shields.io/circleci/build/github/chatwoot/chatwoot" alt="CircleCI Badge">
    <a href="https://hub.docker.com/r/chatwoot/chatwoot/"><img src="https://img.shields.io/docker/pulls/chatwoot/chatwoot" alt="Docker Pull Badge"></a>
  <a href="https://hub.docker.com/r/chatwoot/chatwoot/"><img src="https://img.shields.io/docker/cloud/build/chatwoot/chatwoot" alt="Docker Build Badge"></a>
  <img src="https://img.shields.io/github/commit-activity/m/chatwoot/chatwoot" alt="Commits-per-month">
  <a title="Crowdin" target="_self" href="https://chatwoot.crowdin.com/chatwoot"><img src="https://badges.crowdin.net/e/37ced7eba411064bd792feb3b7a28b16/localized.svg"></a>
  <a href="https://discord.gg/cJXdrwS"><img src="https://img.shields.io/discord/647412545203994635" alt="Discord"></a>
  <a href="https://status.chatwoot.com"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fchatwoot%2Fstatus%2Fmaster%2Fapi%2Fchatwoot%2Fuptime.json" alt="uptime"></a>
  <a href="https://status.chatwoot.com"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fchatwoot%2Fstatus%2Fmaster%2Fapi%2Fchatwoot%2Fresponse-time.json" alt="response time"></a>
  <a href="https://artifacthub.io/packages/helm/chatwoot/chatwoot"><img src="https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/artifact-hub" alt="Artifact HUB"></a>
</p>

<img src="./.github/screenshots/dashboard.png#gh-light-mode-only" width="100%" alt="Chat dashboard dark mode"/>
<img src="./.github/screenshots/dashboard-dark.png#gh-dark-mode-only" width="100%" alt="Chat dashboard"/>

---

Chatwoot is the modern, open-source, and self-hosted customer support platform designed to help businesses deliver exceptional customer support experience. Built for scale and flexibility, Chatwoot gives you full control over your customer data while providing powerful tools to manage conversations across channels.

### ✨ Captain – AI Agent for Support

Supercharge your support with Captain, Chatwoot’s AI agent. Captain helps automate responses, handle common queries, and reduce agent workload—ensuring customers get instant, accurate answers. With Captain, your team can focus on complex conversations while routine questions are resolved automatically. Read more about Captain [here](https://chwt.app/captain-docs).

### 💬 Omnichannel Support Desk

Chatwoot centralizes all customer conversations into one powerful inbox, no matter where your customers reach out from. It supports live chat on your website, email, Facebook, Instagram, Twitter, WhatsApp, Telegram, Line, SMS etc.

### 📚 Help center portal

Publish help articles, FAQs, and guides through the built-in Help Center Portal. Enable customers to find answers on their own, reduce repetitive queries, and keep your support team focused on more complex issues.

### 🗂️ Other features

#### Collaboration & Productivity

- Private Notes and @mentions for internal team discussions.
- Labels to organize and categorize conversations.
- Keyboard Shortcuts and a Command Bar for quick navigation.
- Canned Responses to reply faster to frequently asked questions.
- Auto-Assignment to route conversations based on agent availability.
- Multi-lingual Support to serve customers in multiple languages.
- Custom Views and Filters for better inbox organization.
- Business Hours and Auto-Responders to manage response expectations.
- Teams and Automation tools for scaling support workflows.
- Agent Capacity Management to balance workload across the team.

#### Customer Data & Segmentation
- Contact Management with profiles and interaction history.
- Contact Segments and Notes for targeted communication.
- Campaigns to proactively engage customers.
- Custom Attributes for storing additional customer data.
- Pre-Chat Forms to collect user information before starting conversations.

#### Integrations
- Slack Integration to manage conversations directly from Slack.
- Dialogflow Integration for chatbot automation.
- Dashboard Apps to embed internal tools within Chatwoot.
- Shopify Integration to view and manage customer orders right within Chatwoot.
- Use Google Translate to translate messages from your customers in realtime.
- Create and manage Linear tickets within Chatwoot.

#### Reports & Insights
- Live View of ongoing conversations for real-time monitoring.
- Conversation, Agent, Inbox, Label, and Team Reports for operational visibility.
- CSAT Reports to measure customer satisfaction.
- Downloadable Reports for offline analysis and reporting.


## Documentation

Detailed documentation is available at [chatwoot.com/help-center](https://www.chatwoot.com/help-center).

**This fork’s OIDC docs:** [`docs/oidc-sso.md`](./docs/oidc-sso.md).

## Translation process

The translation process for Chatwoot web and mobile app is managed at [https://translate.chatwoot.com](https://translate.chatwoot.com) using Crowdin. Please read the [translation guide](https://www.chatwoot.com/docs/contributing/translating-chatwoot-to-your-language) for contributing to Chatwoot.

## Branching model

Upstream Chatwoot uses the [git-flow](https://nvie.com/posts/a-successful-git-branching-model/) branching model. The base branch is `develop`.
If you are looking for a stable version, please use the `master` or tags labelled as `v1.x.x`.

**This fork** defaults to `unodos/oidc` (see table at the top of this file).

## Deployment

### Heroku one-click deploy

Deploying Chatwoot to Heroku is a breeze. It's as simple as clicking this button:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/chatwoot/chatwoot/tree/master)

Follow this [link](https://www.chatwoot.com/docs/environment-variables) to understand setting the correct environment variables for the app to work with all the features. There might be breakages if you do not set the relevant environment variables.


### DigitalOcean 1-Click Kubernetes deployment

Chatwoot now supports 1-Click deployment to DigitalOcean as a kubernetes app.

<a href="https://marketplace.digitalocean.com/apps/chatwoot?refcode=f2238426a2a8" alt="Deploy to DigitalOcean">
  <img width="200" alt="Deploy to DO" src="https://www.deploytodo.com/do-btn-blue.svg"/>
</a>

### Other deployment options

For other supported options, checkout our [deployment page](https://chatwoot.com/deploy).

## Security

Looking to report a vulnerability? Please refer our [SECURITY.md](./SECURITY.md) file.

## Community

If you need help or just want to hang out, come, say hi on our [Discord](https://discord.gg/cJXdrwS) server.

## Contributors

**This fork:** first contributor [**@OliAjonjoli**](https://github.com/OliAjonjoli).

Upstream Chatwoot thanks goes to all these [wonderful people](https://www.chatwoot.com/docs/contributors):

<a href="https://github.com/chatwoot/chatwoot/graphs/contributors"><img src="https://opencollective.com/chatwoot/contributors.svg?width=890&button=false" /></a>


*Chatwoot* &copy; 2017-2026, Chatwoot Inc - Released under the MIT License.

*Uno Dos Cloud OIDC fork* — additional work by [@OliAjonjoli](https://github.com/OliAjonjoli).
