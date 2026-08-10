# frozen_string_literal: true

# Uno Dos Cloud fork — user resolution for OpenID Connect (Authentik) SSO.
#
# Mirrors the Enterprise SamlUserBuilder pattern:
#   * Strict mode (OPENID_CONNECT_JIT_ACCOUNT_ID unset): the user must already exist
#     (e.g. created via Settings → Agents → Add Agent). Existing users are confirmed
#     and signed in; unknown emails produce an auth failure.
#   * JIT mode (OPENID_CONNECT_JIT_ACCOUNT_ID=<account id>): unknown emails are
#     auto-created and added to that account as an Agent on first login; existing
#     users are added to the account if they are not already a member.
#
# Users are always matched by email (case-insensitive), consistent with the rest of
# the Uno Dos Cloud platform (Authentik userinfo `email` claim).
module Custom
  class OidcUserBuilder
    class AuthenticationFailed < StandardError; end

    def initialize(auth_hash)
      @auth_hash = auth_hash
      @account_id = ENV['OPENID_CONNECT_JIT_ACCOUNT_ID'].presence
    end

    def perform
      @user = find_or_create_user
      add_user_to_account if @user&.persisted?
      @user
    end

    private

    def find_or_create_user
      return nil if email.blank?

      user = User.from_email(email)
      return user if user.present?
      return nil unless @account_id

      create_user
    end

    def create_user
      User.create(
        email: email,
        name: name,
        provider: 'openid_connect',
        uid: uid,
        password: SecureRandom.hex(32),
        confirmed_at: Time.current
      )
    end

    def add_user_to_account
      return if @account_id.blank?

      account = Account.find_by(id: @account_id)
      return unless account

      account_user = AccountUser.find_or_create_by(user: @user, account: account)
      account_user.update(role: 'agent') if account_user.role.blank?
    end

    def email
      @auth_hash.dig('info', 'email')
    end

    def name
      @auth_hash.dig('info', 'name') || email.to_s.split('@').first
    end

    def uid
      @auth_hash['uid']
    end
  end
end
