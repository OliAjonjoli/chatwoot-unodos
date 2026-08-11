# frozen_string_literal: true

# Uno Dos Cloud fork — OpenID Connect (Authentik) SSO for Chatwoot agents.
#
# This module is prepended to DeviseOverrides::OmniauthCallbacksController through
# Chatwoot's standard extension mechanism (config/initializers/01_inject_enterprise_edition_module.rb):
#   DeviseOverrides::OmniauthCallbacksController.prepend_mod_with('DeviseOverrides::OmniauthCallbacksController')
# resolves 'Custom::DeviseOverrides::OmniauthCallbacksController' because custom/ exists
# (ChatwootApp.extensions => %w[enterprise custom]) and custom/app is on the eager-load paths
# (see config/application.rb).
#
# It composes with the Enterprise SAML module: SAML keeps its own handler (enterprise/...),
# and the openid_connect provider is handled here. Everything else falls through to super.
module Custom
  module DeviseOverrides
    module OmniauthCallbacksController
      def omniauth_success
        return handle_oidc_auth if auth_hash&.dig('provider') == 'openid_connect'

        super
      end

      # Bypass DeviseTokenAuth's session-stash + 307 dance for OIDC — the same approach
      # the Enterprise SAML module uses. The OIDC auth hash (raw userinfo, tokens) is far
      # too large for the cookie session store (ActionDispatch::Cookies::CookieOverflow,
      # ~8KB > 4KB limit), so we must not stash it in the session. Handle the callback
      # in this request instead: env['omniauth.auth'] is already populated by the
      # OmniAuth middleware before this route runs.
      def redirect_callbacks
        return omniauth_success if params[:provider] == 'openid_connect'

        super
      end

      private

      def handle_oidc_auth
        @resource = Custom::OidcUserBuilder.new(auth_hash).perform

        if @resource&.persisted?
          sign_in_user
        else
          redirect_to login_page_url(error: 'oidc-authentication-failed')
        end
      end

      # auth_hash is not defined on the community controller; DeviseTokenAuth provides it
      # (reading request.env['omniauth.auth'] or the session stash from redirect_callbacks).
      def auth_hash
        request.env['omniauth.auth'] || super
      end
    end
  end
end
