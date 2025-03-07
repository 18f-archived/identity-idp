# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Requests
      class TrueIdRequest < DocAuth::LexisNexis::Request
        attr_reader :front_image, :back_image, :selfie_image, :liveness_checking_required,
                    :back_image_required, :document_type

        def initialize(
          config:,
          user_uuid:,
          uuid_prefix:,
          front_image:,
          back_image:,
          selfie_image: nil,
          image_source: nil,
          images_cropped: false,
          liveness_checking_required: false,
          document_type: 'DriversLicense'
        )
          super(config: config, user_uuid: user_uuid, uuid_prefix: uuid_prefix)
          @front_image = front_image
          @back_image = back_image
          @selfie_image = selfie_image
          @image_source = image_source
          @images_cropped = images_cropped
          # when set to required, be sure to pass in selfie_imaged
          @liveness_checking_required = liveness_checking_required
          @document_type = document_type
          @back_image_required = document_type == 'DriversLicense'
        end

        def request_context
          {
            workflow: workflow,
          }
        end

        private

        def body
          document = {
            Document: {
              Front: encode(front_image),
              Back: (encode(back_image) if back_image_required),
              Selfie: (encode(selfie_image) if liveness_checking_required),
              DocumentType: document_type,
            }.compact,
          }

          settings.merge(document).to_json
        end

        def handle_http_response(http_response)
          LexisNexis::Responses::TrueIdResponse.new(
            http_response,
            config,
            liveness_checking_required,
            request_context,
          )
        end

        def method
          :post
        end

        def account_id
          config.trueid_account_id
        end

        def username
          config.trueid_username
        end

        def password
          config.trueid_password
        end

        def workflow
          if @images_cropped
            liveness_checking_required ?
              config.trueid_liveness_nocropping_workflow :
              config.trueid_noliveness_nocropping_workflow
          else
            liveness_checking_required ?
              config.trueid_liveness_cropping_workflow :
              config.trueid_noliveness_cropping_workflow
          end
        end

        def acuant_sdk_source?
          @image_source == ImageSources::ACUANT_SDK
        end

        def encode(image)
          Base64.strict_encode64(image)
        end

        def metric_name
          'lexis_nexis_doc_auth_true_id'
        end

        def timeout
          IdentityConfig.store.lexisnexis_trueid_timeout
        end
      end
    end
  end
end
