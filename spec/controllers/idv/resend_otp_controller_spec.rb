require 'rails_helper'

RSpec.describe Idv::ResendOtpController do
  let(:user) { create(:user) }

  let(:phone) { '+1 (225) 555-5000' }
  let(:user_phone_confirmation) { false }
  let(:delivery_method) { 'sms' }
  let(:user_phone_confirmation_session) do
    Idv::PhoneConfirmationSession.start(
      phone: phone,
      delivery_method: delivery_method,
      user: user,
    )
  end

  before do
    stub_analytics

    sign_in(user)
    stub_verify_steps_one_and_two(user)
    subject.idv_session.vendor_phone_confirmation = true
    subject.idv_session.user_phone_confirmation = user_phone_confirmation
    subject.idv_session.user_phone_confirmation_session = user_phone_confirmation_session
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#create' do
    context 'the user has not selected a delivery method' do
      let(:user_phone_confirmation_session) { nil }

      it 'redirects to otp delivery method selection' do
        post :create
        expect(response).to redirect_to(idv_phone_url)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the enter password step' do
        post :create
        expect(response).to redirect_to(idv_enter_password_path)
      end
    end

    it 'tracks an analytics event' do
      post :create

      expect(@analytics).to have_logged_event(
        'IdV: phone confirmation otp resent',
        hash_including(
          success: true,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(Phonelib.parse(phone).e164),
          otp_delivery_preference: :sms,
          country_code: 'US',
          area_code: '225',
          rate_limit_exceeded: false,
          telephony_response: instance_of(Telephony::Response),
        ),
      )
    end

    context 'Telephony raises an exception' do
      let(:telephony_error) do
        Telephony::TelephonyError.new('error message')
      end
      let(:telephony_response) do
        Telephony::Response.new(
          success: false,
          error: telephony_error,
          extra: { request_id: 'error-request-id' },
        )
      end

      before do
        allow(Telephony).to receive(:send_confirmation_otp).and_return(telephony_response)
      end

      it 'tracks an analytics events' do
        post :create

        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation otp resent',
          hash_including(
            success: false,
            telephony_response: telephony_response,
          ),
        )
        expect(@analytics).to have_logged_event(
          'Vendor Phone Validation failed',
          error: 'Telephony::TelephonyError',
          message: 'error message',
          context: 'idv',
          country: 'US',
        )
      end
    end
  end
end
