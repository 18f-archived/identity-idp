require 'rails_helper'

RSpec.describe OpenidConnectAuthorizeForm do
  subject(:form) do
    OpenidConnectAuthorizeForm.new(
      acr_values: acr_values,
      vtr: vtr,
      client_id: client_id,
      nonce: nonce,
      prompt: prompt,
      redirect_uri: redirect_uri,
      response_type: response_type,
      scope: scope,
      state: state,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method,
      verified_within: verified_within,
    )
  end

  let(:acr_values) { nil }
  let(:vtr) { ['C1'].to_json }
  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:nonce) { SecureRandom.hex }
  let(:prompt) { 'select_account' }
  let(:redirect_uri) { 'gov.gsa.openidconnect.test://result' }
  let(:response_type) { 'code' }
  let(:scope) { 'openid profile' }
  let(:state) { SecureRandom.hex }
  let(:code_challenge) { nil }
  let(:code_challenge_method) { nil }
  let(:verified_within) { nil }

  before do
    allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
  end

  describe '#submit' do
    subject(:result) { form.submit }

    context 'with valid params' do
      it 'is successful' do
        expect(result.to_h).to eq(
          success: true,
          client_id: client_id,
          prompt: 'select_account',
          allow_prompt_login: true,
          redirect_uri: nil,
          unauthorized_scope: true,
          acr_values: '',
          vtr: JSON.parse(vtr),
          scope: 'openid',
          code_digest: nil,
          code_challenge_present: false,
          service_provider_pkce: nil,
          integration_errors: nil,
        )
      end
    end

    context 'with invalid params' do
      context 'with a bad response_type' do
        let(:response_type) { nil }

        it 'is unsuccessful and has error messages' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { response_type: { inclusion: true } },
            client_id: client_id,
            prompt: 'select_account',
            allow_prompt_login: true,
            redirect_uri: "#{redirect_uri}?error=invalid_request&error_description=" \
                          "Response+type+is+not+included+in+the+list&state=#{state}",
            unauthorized_scope: true,
            acr_values: '',
            vtr: JSON.parse(vtr),
            scope: 'openid',
            code_digest: nil,
            code_challenge_present: false,
            service_provider_pkce: nil,
            integration_errors: {
              error_details: ['Response type is not included in the list'],
              error_types: [:response_type],
              event: :oidc_request_authorization,
              integration_exists: true,
              request_issuer: client_id,
            },
          )
        end
      end
    end

    context 'with a bad redirect_uri' do
      let(:redirect_uri) { 'https://wrongurl.com' }

      it 'has errors and does not redirect to the bad redirect_uri' do
        expect(result.errors[:redirect_uri])
          .to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))

        expect(result.extra[:redirect_uri]).to be_nil
      end
    end

    context 'when use_vot_in_sp_requests flag is false' do
      before do
        allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(false)
      end

      context 'with only a vtr param' do
        let(:vtr) { ['C1.P1'].to_json }
        let(:acr_values) { nil }

        it 'is invalid' do
          expect(form.vtr).to be_nil
          expect(form.valid?).to eq(false)
          expect(form.errors[:acr_values])
            .to include(t('openid_connect.authorization.errors.no_valid_acr_values'))
          expect(form.errors[:vtr]).to be_empty
        end
      end

      context 'with a vtr and acr_values param' do
        let(:vtr) { ['C1.P1'].to_json }
        let(:acr_values) { Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF }

        it 'uses the acr_values param and ignores vtr' do
          expect(form.vtr).to be_nil
          expect(form.valid?).to eq(true)
        end
      end

      context 'with only an acr_values param' do
        let(:vtr) { nil }
        let(:acr_values) { Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF }

        it 'uses the acr_values param' do
          expect(form.valid?).to eq(true)
        end
      end
    end
  end

  describe '#valid?' do
    subject(:valid?) { form.valid? }

    context 'with all valid attributes' do
      it { expect(valid?).to eq(true) }
      it 'has no errors' do
        valid?
        expect(form.errors).to be_blank
      end
    end

    context 'with an invalid vtr' do
      let(:vtr) { ['A1.B2.C3'].to_json }

      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:vtr])
          .to include(t('openid_connect.authorization.errors.no_valid_vtr'))
      end
    end

    context 'with no valid acr_values' do
      let(:acr_values) { 'abc def' }
      let(:vtr) { nil }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values])
          .to include(t('openid_connect.authorization.errors.no_valid_acr_values'))
      end
    end

    context 'with no authorized vtr components' do
      let(:vtr) { ['C1.P1'].to_json }
      let(:client_id) { 'urn:gov:gsa:openidconnect:test:loa1' }

      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values])
          .to include(t('openid_connect.authorization.errors.no_auth'))
      end
    end

    context 'with no authorized acr_values' do
      let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
      let(:vtr) { nil }
      let(:client_id) { 'urn:gov:gsa:openidconnect:test:loa1' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values])
          .to include(t('openid_connect.authorization.errors.no_auth'))
      end
    end

    context 'with unknown acr_values' do
      let(:acr_values) { 'unknown-value' }
      let(:vtr) { nil }

      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values])
          .to include(t('openid_connect.authorization.errors.no_valid_acr_values'))
      end

      context 'with a known IAL value' do
        let(:acr_values) do
          [
            'unknown-value',
            Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
          ].join(' ')
        end

        it 'is valid' do
          expect(valid?).to eq(true)
        end
      end
    end

    context 'with ialmax requested' do
      let(:acr_values) { Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF }
      let(:vtr) { nil }

      context 'with a service provider not in the allow list' do
        it 'has errors' do
          expect(valid?).to eq false
          expect(form.errors[:acr_values])
            .to include(t('openid_connect.authorization.errors.no_auth'))
        end
      end

      context 'with a service provider on the allow list' do
        before do
          expect(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [client_id] }
        end

        it 'has no errors' do
          expect(valid?).to eq true
          expect(form.errors).to be_blank
        end
      end
    end

    context 'when facial match is requested' do
      shared_examples 'allows facial match IAL only if sp is authorized' do |facial_match_ial|
        let(:acr_values) { facial_match_ial }

        context "when the IAL requested is #{facial_match_ial}" do
          context 'when facial match general availability is turned off' do
            before do
              allow(IdentityConfig.store).to receive(
                :facial_match_general_availability_enabled,
              ).and_return(false)
            end

            it 'fails with a not authorized error' do
              expect(form).not_to be_valid
              expect(form.errors[:acr_values])
                .to include(t('openid_connect.authorization.errors.no_auth'))
            end
          end

          context 'when facial match general availability is turned on' do
            it 'succeeds validation' do
              expect(form).to be_valid
            end
          end
        end
      end

      it_behaves_like 'allows facial match IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF

      it_behaves_like 'allows facial match IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF

      context 'when using semantic acr_values' do
        it_behaves_like 'allows facial match IAL only if sp is authorized',
                        Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR

        it_behaves_like 'allows facial match IAL only if sp is authorized',
                        Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
      end
    end

    context 'with aal but not ial requested via acr_values' do
      let(:acr_values) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }
      let(:vtr) { nil }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:acr_values])
          .to include(t('openid_connect.authorization.errors.missing_ial'))
      end
    end

    context 'with an unknown client_id' do
      let(:client_id) { 'not_a_real_client_id' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:client_id])
          .to include(t('openid_connect.authorization.errors.bad_client_id'))
      end
    end

    context 'nonce' do
      context 'without a nonce' do
        let(:nonce) { nil }
        it { expect(valid?).to eq(false) }
      end

      context 'with a nonce that is shorter than RANDOM_VALUE_MINIMUM_LENGTH characters' do
        let(:nonce) { '1' * (OpenidConnectAuthorizeForm::RANDOM_VALUE_MINIMUM_LENGTH - 1) }
        it { expect(valid?).to eq(false) }
      end
    end

    context 'when prompt is not select_account or login' do
      let(:prompt) { 'aaa' }
      it { expect(valid?).to eq(false) }
    end

    context 'when prompt is not given' do
      let(:prompt) { nil }

      it { expect(valid?).to eq(true) }
    end

    context 'when prompt is login and allowed by sp' do
      let(:prompt) { 'login' }
      before do
        allow_any_instance_of(ServiceProvider).to receive(:allow_prompt_login).and_return true
      end

      it { expect(valid?).to eq(true) }
    end

    context 'when prompt is login but not allowed by sp' do
      let(:prompt) { 'login' }
      before do
        allow_any_instance_of(ServiceProvider).to receive(:allow_prompt_login).and_return false
      end

      it { expect(valid?).to eq(false) }
    end

    context 'when prompt is blank' do
      let(:prompt) { '' }
      it { expect(valid?).to eq(false) }
    end

    context 'when scope does not contain valid scopes' do
      let(:scope) { 'foo bar baz' }
      it 'has errors' do
        expect(valid?).to eq(false)
        expect(form.errors[:scope])
          .to include(t('openid_connect.authorization.errors.no_valid_scope'))
      end
    end

    context 'when scope is unauthorized and we block unauthorized scopes' do
      let(:scope) { 'email profile' }

      it 'has errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(true)
        expect(valid?).to eq(false)
        expect(form.errors[:scope])
          .to include(t('openid_connect.authorization.errors.unauthorized_scope'))
      end
    end

    context 'when scope is good and we block unauthorized scopes' do
      let(:scope) { 'email' }

      it 'does not have errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(false)
        expect(valid?).to eq(true)
      end
    end

    context 'when scope is unauthorized and we do not block unauthorized scopes' do
      let(:scope) { 'email profile' }

      it 'does not have errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(false)
        expect(valid?).to eq(true)
      end
    end

    context 'when scope includes profile:verified_at but the sp is only ial1' do
      let(:client_id) { 'urn:gov:gsa:openidconnect:test:loa1' }
      let(:vtr) { ['C1'].to_json }
      let(:scope) { 'email profile:verified_at' }

      it 'has errors' do
        allow(IdentityConfig.store).to receive(:unauthorized_scope_enabled).and_return(true)
        expect(valid?).to eq(false)
        expect(form.errors[:scope])
          .to include(t('openid_connect.authorization.errors.unauthorized_scope'))
      end
    end

    context 'redirect_uri' do
      context 'without a redirect_uri' do
        let(:redirect_uri) { nil }
        it { expect(valid?).to eq(false) }
      end

      context 'with a malformed redirect_uri' do
        let(:redirect_uri) { ':aaaa' }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:redirect_uri])
            .to include(t('openid_connect.authorization.errors.redirect_uri_invalid'))
        end
      end

      context 'with a redirect_uri not registered to the client' do
        let(:redirect_uri) { 'http://localhost:3000/test' }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:redirect_uri])
            .to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
        end
      end

      context 'with a redirect_uri that only partially matches any registered redirect_uri' do
        let(:redirect_uri) { 'gov.gsa.openidconnect.test://result/more/extra' }
        it { expect(valid?).to eq(false) }
      end
    end

    context 'when response_type is not code' do
      let(:response_type) { 'aaa' }
      it { expect(valid?).to eq(false) }
    end

    context 'state' do
      context 'without a state' do
        let(:state) { nil }
        it { expect(valid?).to eq(false) }
      end

      context 'with a state that is shorter than RANDOM_VALUE_MINIMUM_LENGTH characters' do
        let(:state) { '1' * (OpenidConnectAuthorizeForm::RANDOM_VALUE_MINIMUM_LENGTH - 1) }
        it { expect(valid?).to eq(false) }
      end
    end

    context 'PKCE' do
      let(:code_challenge) { 'abcdef' }
      let(:code_challenge_method) { 'S256' }

      context 'code_challenge but no code_challenge_method' do
        let(:code_challenge_method) { nil }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:code_challenge_method]).to be_present
        end
      end

      context 'bad code_challenge_method' do
        let(:code_challenge_method) { 'plain' }
        it 'has errors' do
          expect(valid?).to eq(false)
          expect(form.errors[:code_challenge_method]).to be_present
        end
      end
    end
  end

  describe '#acr_values' do
    let(:vtr) { nil }
    let(:acr_value_list) do
      [
        Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
        Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      ]
    end
    let(:acr_values) { acr_value_list.join(' ') }

    it 'is parsed into an array of valid ACR values' do
      expect(form.acr_values).to eq acr_value_list
    end

    context 'when an unknown acr value is included' do
      let(:acr_value_list) do
        [
          Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
        ]
      end
      let(:acr_values) { (acr_value_list + ['fake-value']).join(' ') }

      it 'is parsed into an array of valid ACR values' do
        expect(form.acr_values).to eq acr_value_list
      end
    end

    context 'when the only value is an unknown acr value' do
      let(:acr_values) { 'fake_value' }

      it 'returns an empty array for acr_values' do
        expect(form.acr_values).to eq([])
      end
    end
  end

  describe '#requested_aal_value' do
    context 'with ACR values' do
      let(:vtr) { nil }
      context 'when AAL2 passed' do
        let(:acr_values) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }

        it 'returns AAL2' do
          expect(form.requested_aal_value).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
        end
      end

      context 'when AAL2_PHISHING_RESISTANT passed' do
        let(:acr_values) { Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF }

        it 'returns AAL2+Phishing Resistant' do
          expect(form.requested_aal_value).to eq(
            Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'when AAL2_HSPD12 passed' do
        let(:acr_values) { Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF }

        it 'returns AAL2+HSPD12' do
          expect(form.requested_aal_value).to eq(
            Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'when AAL3 passed' do
        let(:acr_values) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }

        it 'returns AAL3' do
          expect(form.requested_aal_value).to eq(Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF)
        end
      end

      context 'when AAL3_HSPD12 passed' do
        let(:acr_values) { Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF }

        it 'returns AAL3+HSPD12' do
          expect(form.requested_aal_value).to eq(
            Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'when AAL3_HSPD12 and AAL2_HSPD12 passed' do
        let(:acr_values) do
          [Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
           Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF].join(' ')
        end

        it 'returns AAL2+HSPD12' do
          expect(form.requested_aal_value).to eq(
            Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'when AAL2 and AAL2_PHISHING_RESISTANT passed' do
        let(:phishing_resistant) do
          Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF
        end

        let(:acr_values) do
          "#{Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF}
          #{phishing_resistant}"
        end

        it 'returns AAL2+HSPD12' do
          expect(form.requested_aal_value).to eq(phishing_resistant)
        end
      end

      context 'when AAL2_PHISHING_RESISTANT and AAL2 passed' do
        # this is the same as the previous test, just reverse ordered
        # AAL values, to ensure it doesn't just take the 2nd AAL.
        let(:phishing_resistant) do
          Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF
        end

        let(:acr_values) do
          "#{phishing_resistant}
          #{Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF}"
        end

        it 'returns AAL2+HSPD12' do
          requested_aal_value = form.requested_aal_value
          expect(requested_aal_value).to eq(phishing_resistant)
        end
      end

      context 'when no values are passed in' do
        let(:acr_values) { '' }

        it 'returns the default AAL value' do
          expect(form.requested_aal_value).to eq(
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'when only an unknown value is passed in' do
        let(:acr_values) { 'fake-value' }

        it 'returns the default AAL value' do
          expect(form.requested_aal_value).to eq(
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end
    end
  end

  describe '#verified_within' do
    let(:acr_values) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }

    context 'the issuer is allowed to use verified_within' do
      before do
        allow(IdentityConfig.store).to receive(:allowed_verified_within_providers)
          .and_return([client_id])
      end

      context 'without a verified_within' do
        let(:verified_within) { nil }

        it 'is valid' do
          expect(form.valid?).to eq(true)
          expect(form.verified_within).to eq(nil)
        end
      end

      context 'with a duration that is too short (<30 days)' do
        let(:verified_within) { '2d' }

        it 'has errors' do
          expect(form.valid?).to eq(false)
          expect(form.errors[:verified_within])
            .to eq(['value must be at least 30 days or older'])
        end
      end

      context 'with a format in days' do
        let(:verified_within) { '45d' }

        it 'parses the value as a number of days' do
          expect(form.valid?).to eq(true)
          expect(form.verified_within).to eq(45.days)
        end
      end

      context 'with a verified_within with a bad format' do
        let(:verified_within) { 'bbb' }

        it 'has errors' do
          expect(form.valid?).to eq(false)
          expect(form.errors[:verified_within]).to eq(['Unrecognized format for verified_within'])
        end
      end
    end

    context 'the issuer is not allowed to use verified_within' do
      before do
        allow(IdentityConfig.store).to receive(:allowed_verified_within_providers)
          .and_return([])
      end

      context 'without a verified_within' do
        let(:verified_within) { nil }

        it 'verified_within is not set' do
          expect(form.valid?).to eq(true)
          expect(form.verified_within).to be nil
        end
      end

      context 'with a duration that is too short (<30 days)' do
        let(:verified_within) { '2d' }

        it 'verified_within is not set' do
          expect(form.valid?).to eq(true)
          expect(form.verified_within).to be nil
        end
      end

      context 'with a format in days' do
        let(:verified_within) { '45d' }

        it 'verified_within is not set' do
          expect(form.valid?).to eq(true)
          expect(form.verified_within).to be nil
        end
      end

      context 'with a verified_within with a bad format' do
        let(:verified_within) { 'bbb' }

        it 'verified_within is not set' do
          expect(form.valid?).to eq(true)
          expect(form.verified_within).to be nil
        end
      end
    end
  end

  describe '#client_id' do
    it 'returns the form client_id' do
      form = OpenidConnectAuthorizeForm.new(client_id: 'foobar')

      expect(form.client_id).to eq 'foobar'
    end
  end

  describe '#link_identity_to_service_provider' do
    let(:user) { create(:user) }
    let(:rails_session_id) { SecureRandom.hex }

    context 'with PKCE' do
      let(:code_challenge) { 'abcdef' }
      let(:code_challenge_method) { 'S256' }

      it 'records the code_challenge on the identity' do
        form.link_identity_to_service_provider(
          current_user: user,
          ial: 1,
          rails_session_id: rails_session_id,
          email_address_id: 4,
        )

        identity = user.identities.where(service_provider: client_id).first

        expect(identity.code_challenge).to eq(code_challenge)
        expect(identity.nonce).to eq(nonce)
        expect(identity.ial).to eq(1)
        expect(identity.acr_values).to eq ''
        expect(identity.vtr).to eq ['C1'].to_json
      end
    end
  end

  describe '#success_redirect_uri' do
    let(:user) { create(:user) }
    let(:rails_session_id) { SecureRandom.hex }

    context 'when the identity has been linked' do
      before do
        form.link_identity_to_service_provider(
          current_user: user,
          ial: 1,
          rails_session_id: rails_session_id,
          email_address_id: 4,
        )
      end

      it 'returns a redirect URI with the code from the identity session_uuid' do
        identity = user.identities.where(service_provider: client_id).first

        expect(form.success_redirect_uri)
          .to eq "#{redirect_uri}?code=#{identity.session_uuid}&state=#{state}"
      end

      it 'logs a hash of the code in the analytics params' do
        code = UriService.params(form.success_redirect_uri)[:code]

        expect(form.submit.extra[:code_digest]).to eq(Digest::SHA256.hexdigest(code))
      end
    end

    context 'when the identity has not been linked' do
      it 'returns nil' do
        expect(form.success_redirect_uri).to be_nil
      end
    end
  end

  describe '#service_provider' do
    context 'empty client_id' do
      let(:client_id) { '' }

      it 'does not query the database' do
        expect(ServiceProvider).to_not receive(:find_by)

        expect(form.service_provider).to be_nil
      end
    end
  end
end
