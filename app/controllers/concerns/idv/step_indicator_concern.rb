# frozen_string_literal: true

module Idv
  module StepIndicatorConcern
    extend ActiveSupport::Concern

    STEP_INDICATOR_STEPS = [
      { name: :getting_started },
      { name: :verify_id },
      { name: :verify_info },
      { name: :verify_phone },
      { name: :re_enter_password },
    ].freeze

    STEP_INDICATOR_STEPS_GPO = [
      { name: :getting_started },
      { name: :verify_id },
      { name: :verify_info },
      { name: :verify_address },
      { name: :secure_account },
    ].freeze

    STEP_INDICATOR_STEPS_IPP = [
      { name: :find_a_post_office },
      { name: :verify_info },
      { name: :verify_phone },
      { name: :re_enter_password },
      { name: :go_to_the_post_office },
    ].freeze

    included do
      helper_method :step_indicator_steps
    end

    def step_indicator_steps
      if in_person_proofing?
        Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP
      elsif gpo_address_verification?
        Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO
      else
        Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS
      end
    end

    private

    def in_person_proofing?
      current_user&.has_in_person_enrollment?
    end

    def gpo_address_verification?
      # This can be used in a context where user_session and idv_session are not available
      # (hybrid flow), so check for current_user before accessing them.
      return false unless current_user
      return true if current_user.gpo_verification_pending_profile?

      return idv_session.verify_by_mail?
    end
  end
end
