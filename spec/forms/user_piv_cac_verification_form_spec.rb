require 'rails_helper'

RSpec.describe UserPivCacVerificationForm do
  let(:form) { described_class.new(user: user, token: token, nonce: nonce) }
  let(:user) { create(:user, :with_piv_or_cac) }
  let(:nonce) { 'once' }

  describe '#submit' do
    before(:each) do
      allow(PivCacService).to receive(:decode_token).with(token) { token_response }
    end

    context 'when token is valid' do
      let(:token) { 'good-token' }
      let(:x509_dn_uuid) { 'some-random-uuid' }

      let(:token_response) do
        {
          'uuid' => x509_dn_uuid,
          'subject' => 'x509-subject',
          'nonce' => nonce,
          'key_id' => 'foo',
        }
      end

      context 'and a user has no piv/cac associated' do
        let(:user) { create(:user) }

        it 'returns FormResponse with success: false' do
          result = form.submit
          expect(result.to_h).to eq(
            success: false,
            error_details: { user: { no_piv_cac_associated: true } },
            piv_cac_configuration_id: nil,
            multi_factor_auth_method_created_at: nil,
            piv_cac_configuration_dn_uuid: nil,
            key_id: nil,
          )

          expect(form.error_type).to eq 'user.no_piv_cac_associated'
        end
      end

      context 'and a user has a different piv/cac associated' do
        let(:user) { create(:user, :with_piv_or_cac) }

        it 'returns FormResponse with success: false' do
          result = form.submit

          expect(result.to_h).to eq(
            success: false,
            error_details: { user: { piv_cac_mismatch: true } },
            multi_factor_auth_method_created_at: nil,
            piv_cac_configuration_id: nil,
            piv_cac_configuration_dn_uuid: 'some-random-uuid',
            key_id: 'foo',
          )
          expect(form.error_type).to eq 'user.piv_cac_mismatch'
        end
      end

      context 'and the correct piv/cac is presented' do
        let(:user) { create(:user, :with_piv_or_cac) }
        let(:x509_dn_uuid) { user.piv_cac_configurations.first.x509_dn_uuid }
        let(:result) { instance_double(FormResponse) }
        let(:piv_cac_configuration) { user.piv_cac_configurations.first }

        it 'returns FormResponse with success: true' do
          result = form.submit
          expect(result.to_h).to eq(
            success: true,
            piv_cac_configuration_id: piv_cac_configuration.id,
            multi_factor_auth_method_created_at: piv_cac_configuration.created_at.strftime('%s%L'),
            key_id: 'foo',
            piv_cac_configuration_dn_uuid: x509_dn_uuid,
          )
        end

        context 'when nonce is bad' do
          before(:each) do
            form.nonce = form.nonce + 'X'
          end

          it 'returns FormResponse with success: false' do
            result = form.submit
            expect(result.to_h).to eq(
              success: false,
              error_details: { token: { invalid: true } },
              piv_cac_configuration_id: nil,
              multi_factor_auth_method_created_at: nil,
              piv_cac_configuration_dn_uuid: nil,
              key_id: 'foo',
            )

            expect(Event).to_not receive(:create)
            expect(form.error_type).to eq 'token.invalid'
          end
        end
      end
    end

    context 'when token is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => nonce, key_id: 'foo' }
      end

      it 'returns FormResponse with success: false' do
        result = form.submit
        expect(Event).to_not receive(:create)
        expect(form.error_type).to eq 'token.bad'
        expect(result.to_h).to eq(
          success: false,
          error_details: { token: { bad: true } },
          multi_factor_auth_method_created_at: nil,
          piv_cac_configuration_dn_uuid: nil,
          piv_cac_configuration_id: nil,
          key_id: nil,
        )
      end
    end

    context 'when token is missing' do
      let(:token) {}

      it 'returns FormResponse with success: false' do
        result = form.submit
        expect(Event).to_not receive(:create)

        expect(result.to_h).to eq(
          success: false,
          error_details: { token: { blank: true } },
          multi_factor_auth_method_created_at: nil,
          piv_cac_configuration_id: nil,
          piv_cac_configuration_dn_uuid: nil,
          key_id: nil,
        )
      end
    end
  end
end
