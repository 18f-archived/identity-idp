# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class StateIdAddressPlugin
        attr_reader :proofer, :sp_cost_token

        SECONDARY_ID_ADDRESS_MAP = {
          identity_doc_address1: :address1,
          identity_doc_address2: :address2,
          identity_doc_city: :city,
          identity_doc_address_state: :state,
          identity_doc_zipcode: :zipcode,
        }.freeze

        def initialize(
          proofer:,
          sp_cost_token:
        )
          @proofer = proofer
          @sp_cost_token = sp_cost_token
        end

        def call(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result:,
          ipp_enrollment_in_progress:,
          timer:
        )
          if same_address_as_id?(applicant_pii) && ipp_enrollment_in_progress
            return residential_address_resolution_result
          end

          return resolution_cannot_pass unless residential_address_resolution_result.success?

          applicant_pii_with_state_id_address =
            if ipp_enrollment_in_progress
              with_state_id_address(applicant_pii)
            else
              applicant_pii
            end

          timer.time('resolution') do
            proofer.proof(applicant_pii_with_state_id_address)
          end.tap do |result|
            Db::SpCost::AddSpCost.call(
              current_sp,
              :lexis_nexis_resolution,
              transaction_id: result.transaction_id,
            )
          end
        end

        def resolution_cannot_pass
          Proofing::Resolution::Result.new(
            success: false, errors: {}, exception: nil, vendor_name: 'ResolutionCannotPass',
          )
        end

        def same_address_as_id?(applicant_pii)
          applicant_pii[:same_address_as_id].to_s == 'true'
        end

        # Make a copy of pii with the user's state ID address overwriting the address keys
        # Need to first remove the address keys to avoid key/value collision
        def with_state_id_address(pii)
          pii.except(*SECONDARY_ID_ADDRESS_MAP.values)
            .transform_keys(SECONDARY_ID_ADDRESS_MAP)
        end
      end
    end
  end
end
