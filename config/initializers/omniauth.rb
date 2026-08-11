# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }

  # Uno Dos Cloud fork: OpenID Connect (Authentik) SSO.
  # Enabled only when OPENID_CONNECT_ISSUER is set — otherwise this build behaves
  # exactly like stock Chatwoot (env-gated so one image serves both modes).
  if ENV['OPENID_CONNECT_ISSUER'].present?
    provider :openid_connect, {
      # String name so auth_hash['provider'] is 'openid_connect' (not :openid_connect).
      # The custom callback also compares via .to_s as a belt-and-suspenders guard.
      name: 'openid_connect',
      issuer: ENV['OPENID_CONNECT_ISSUER'],
      scope: ENV.fetch('OPENID_CONNECT_SCOPE', 'openid email profile'),
      response_type: :code,
      discovery: true,
      client_options: {
        identifier: ENV['OPENID_CONNECT_CLIENT_ID'],
        secret: ENV['OPENID_CONNECT_CLIENT_SECRET'],
        redirect_uri: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/omniauth/openid_connect/callback"
      }
    }
  end
end
