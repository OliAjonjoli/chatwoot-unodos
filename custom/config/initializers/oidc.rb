# frozen_string_literal: true

# Uno Dos Cloud fork — allow GET-initiated OIDC SSO.
#
# OmniAuth 2.x defaults `allowed_request_methods` to `[:post]` (CSRF hardening), which
# rejects the plain GET links used by login buttons. Chatwoot's own flows work around
# this: the Google button builds the authorize URL client-side, and the enterprise
# SAML flow redirects to `/auth/saml` with GET. For consistency with the SAML pattern
# (and to keep our login button a simple link), allow GET when OIDC is enabled.
#
# The OIDC strategy still protects the callback: it stores `state`/`nonce` in the
# session and validates them before exchanging the code (omniauth_openid_connect).
# Gating on OPENID_CONNECT_ISSUER keeps the change inert when the fork feature is off.
if ENV['OPENID_CONNECT_ISSUER'].present?
  OmniAuth.config.allowed_request_methods = %i[get post]
end
