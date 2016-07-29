require 'rails_helper'

describe AttributeAsserter do
  include SamlAuthHelper

  let(:loa1_user) { create(:user, :signed_up) }
  let(:user) { create(:profile, :active, :verified, first_name: 'Jane').user }
  let(:service_provider) { ServiceProvider.new(sp1_saml_settings.issuer) }
  let(:raw_authn_request) { URI.decode loa3_authnrequest.split('SAMLRequest').last }
  let(:authn_request) do
    SamlIdp::Request.from_deflated_request(raw_authn_request)
  end

  describe '#build' do
    context 'verified user' do
      let(:subject) { described_class.new(user, service_provider, authn_request) }

      context 'custom bundle includes email, mobile' do
        before do
          allow_any_instance_of(ServiceProvider).to receive(:attribute_bundle).and_return(
            %w(email mobile first_name)
          )
          subject.build
        end

        it 'includes all defined attributes' do
          expect(user.asserted_attributes).to have_key :email
          expect(user.asserted_attributes).to have_key :mobile
          expect(user.asserted_attributes).to have_key :first_name
          expect(user.asserted_attributes).to_not have_key :last_name
        end

        it 'creates getter function' do
          expect(user.asserted_attributes[:first_name][:getter].call(user)).to eq 'Jane'
        end
      end

      context 'Service Provider does not specify bundle' do
        before do
          allow_any_instance_of(ServiceProvider).to receive(:attribute_bundle).and_return(nil)
          subject.build
        end

        context 'authn request does not specify bundle' do
          it 'contains DEFAULT_BUNDLE' do
            expect(user.asserted_attributes.keys).to match_array(
              AttributeAsserter::DEFAULT_BUNDLE + [:uuid]
            )
          end
        end

        context 'authn request specifies bundle' do
          let(:raw_authn_request) do
            URI.decode auth_request.create(loa3_with_bundle_saml_settings).split('SAMLRequest').last
          end

          it 'uses authn request bundle' do
            expect(user.asserted_attributes).to have_key :email
            expect(user.asserted_attributes).to have_key :mobile
            expect(user.asserted_attributes).to have_key :first_name
            expect(user.asserted_attributes).to have_key :last_name
            expect(user.asserted_attributes).to have_key :ssn
            expect(user.asserted_attributes).to_not have_key :dob
          end
        end
      end

      context 'Service Provider specifies empty bundle' do
        before do
          allow_any_instance_of(ServiceProvider).to receive(:attribute_bundle).and_return([])
          subject.build
        end

        it 'contains UUID only' do
          expect(user.asserted_attributes.keys).to eq([:uuid])
        end
      end

      context 'custom bundle has invalid attribute name' do
        before do
          allow_any_instance_of(ServiceProvider).to receive(:attribute_bundle).and_return(
            %w(email foo)
          )
          subject.build
        end

        it 'silently skips invalid attribute name' do
          expect(user.asserted_attributes).to have_key :email
          expect(user.asserted_attributes).to_not have_key :foo
        end
      end
    end

    context 'un-verified user' do
      let(:subject) { described_class.new(loa1_user, service_provider, authn_request) }

      context 'custom bundle does not include email, mobile' do
        before do
          allow_any_instance_of(ServiceProvider).to receive(:attribute_bundle).and_return(
            %w(first_name last_name)
          )
          subject.build
        end

        it 'includes only UUID' do
          expect(loa1_user.asserted_attributes).to have_key :uuid
          expect(loa1_user.asserted_attributes).to_not have_key :email
          expect(loa1_user.asserted_attributes).to_not have_key :mobile
          expect(loa1_user.asserted_attributes).to_not have_key :first_name
          expect(loa1_user.asserted_attributes).to_not have_key :last_name
        end
      end

      context 'custom bundle includes email, mobile' do
        before do
          allow_any_instance_of(ServiceProvider).to receive(:attribute_bundle).and_return(
            %w(first_name last_name email mobile)
          )
          subject.build
        end

        it 'includes UUID, email, mobile only' do
          expect(loa1_user.asserted_attributes).to have_key :uuid
          expect(loa1_user.asserted_attributes).to have_key :email
          expect(loa1_user.asserted_attributes).to have_key :mobile
          expect(loa1_user.asserted_attributes).to_not have_key :first_name
          expect(loa1_user.asserted_attributes).to_not have_key :last_name
        end
      end
    end
  end
end
