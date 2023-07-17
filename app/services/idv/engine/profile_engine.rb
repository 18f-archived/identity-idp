module Idv::Engine
  # An implementation of Idv::Engine that uses the Profile model, IdvSession, and user_session
  # as its backing data store.
  class ProfileEngine < Base
    attr_reader :idv_session, :user, :user_session

    def initialize(user:, idv_session: nil, user_session: nil)
      raise 'user is required' unless user
      @user = user
      @idv_session = idv_session
      @user_session = user_session
    end

    on :auth_user_changed_password do |params|
      assert_user_session_available

      if user.active_profile
        ActiveProfileEncryptor.new(user, user_session, params.password).call
      end
    end

    on :auth_user_reset_password do
      user.proofing_component&.destroy
    end

    on :idv_gpo_user_requested_letter do
      update_idv_session(
        address_verification_mechanism: :gpo,
      )
    end

    on :idv_user_entered_ssn do |params|
      update_flow_session_pii_from_doc(
        ssn: params.ssn,
      )
    end

    on :idv_fraud_threatmetrix_check_completed do |params|
      update_idv_session(
        threatmetrix_review_status: params.threatmetrix_review_status,
      )

      update_proofing_components(
        threatmetrix: FeatureManagement.proofing_device_profiling_collecting_enabled?,
        threatmetrix_review_status: params.threatmetrix_review_status,
      )
    end

    on :idv_user_started do
      update_idv_session(
        welcome_visited: true,
      )
    end

    on :idv_user_consented_to_share_pii do
      update_idv_session(
        idv_consent_given: true,
      )
    end

    protected

    def assert_no_active_profile
      raise 'User has an active profile' if user.active_profile
    end

    def assert_idv_session_available
      raise 'idv_session is not available' unless idv_session
    end

    def assert_user_session_available
      raise 'user_session is not available' unless user_session
    end

    def build_verification
      Verification.new(
        identity_verified?: !!user.active_profile,
        user_has_consented_to_share_pii?:
          user_has_active_or_pending_profile? || idv_session&.idv_consent_given,
      )
    end

    def flow_session
      assert_user_session_available
      user_session['idv/doc_auth'] ||= {}
    end

    def update_flow_session(fields)
      fields.each_pair do |key, value|
        flow_session[key] = value
      end
    end

    def update_flow_session_pii_from_doc(fields)
      pii_from_doc = flow_session[:pii_from_doc]
      flow_session[:pii_from_doc] = (pii_from_doc || {}).merge(fields)
    end

    def update_idv_session(fields)
      assert_idv_session_available
      assert_no_active_profile

      fields.each_pair do |key, value|
        idv_session.send("#{key}=".to_sym, value)
      end
    end

    def update_proofing_components(fields)
      ProofingComponent.
        create_or_find_by(user_id: user.id).
        update(fields)
    end

    def user_has_active_or_pending_profile?
      !!(user.active_profile || user.pending_profile)
    end
  end
end
