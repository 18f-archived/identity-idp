require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include RenderConditionConcern
      include UspsInPersonProofing
      include EffectiveUser
      include UspsInPersonProofing

      check_or_render_not_found -> { InPersonConfig.enabled? }

      before_action :confirm_authenticated_for_api, only: [:update]

      rescue_from Faraday::TimeoutError,
                  Faraday::BadRequestError,
                  Faraday::ForbiddenError,
                  StandardError,
                  with: :handle_error

      # retrieve the list of nearby IPP Post Office locations with a POST request
      def index
        response = []
        if IdentityConfig.store.arcgis_search_enabled
          candidate = UspsInPersonProofing::Applicant.new(
            address: search_params['street_address'],
            city: search_params['city'], state: search_params['state'],
            zip_code: search_params['zip_code']
          )
          response = proofer.request_facilities(candidate)
          if response.length > 0
            analytics.idv_in_person_locations_searched(
              success: true,
              result_total: response.length,
            )
          else
            analytics.idv_in_person_locations_searched(
              success: false, errors: 'No USPS locations found',
            )
          end
        else
          response = proofer.request_pilot_facilities
        end
        render json: response.to_json
      end

      def proofer
        @proofer ||= EnrollmentHelper.usps_proofer
      end

      # save the Post Office location the user selected to an enrollment
      def update
        enrollment.update!(
          selected_location_details: update_params.as_json,
          issuer: current_sp&.issuer,
        )

        render json: { success: true }, status: :ok
      end

      protected

      def handle_error(err)
        remapped_error = {
          Faraday::TimeoutError => :unprocessable_entity,
          Faraday::BadRequestError => :unprocessable_entity,
          Faraday::ForbiddenError => :unprocessable_entity,
          ActionController::InvalidAuthenticityToken => :unprocessable_entity,
        }[err.class] || :internal_server_error

        analytics.idv_in_person_locations_request_failure(
          api_status_code: Rack::Utils.status_code(remapped_error),
          exception_class: err.class,
          exception_message: err.message,
          response_body_present: err.respond_to?(:response_body) && err.response_body.present?,
          response_body: err.respond_to?(:response_body) && err.response_body,
          response_status_code: err.respond_to?(:response_status) && err.response_status,
        )
        render json: {}, status: remapped_error
      end

      def confirm_authenticated_for_api
        render json: { success: false }, status: :unauthorized if !effective_user
      end

      def enrollment
        InPersonEnrollment.find_or_initialize_by(
          user: effective_user,
          status: :establishing,
          profile: nil,
        )
      end

      def search_params
        params.require(:address).permit(
          :street_address,
          :city,
          :state,
          :zip_code,
        )
      end

      def update_params
        params.require(:usps_location).permit(
          :formatted_city_state_zip,
          :name,
          :phone,
          :saturday_hours,
          :street_address,
          :sunday_hours,
          :weekday_hours,
        )
      end
    end
  end
end
