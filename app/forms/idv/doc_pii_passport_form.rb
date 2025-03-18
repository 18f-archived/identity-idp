# frozen_string_literal: true

module Idv
  class DocPiiPassportForm
    include ActiveModel::Model

    validates :birth_place,
              :passport_expiration,
              :passport_issued,
              :state_id_type,
              :issuing_country_code,
              :nationality_code,
              :personal_number,
              :mrz,
              presence: true

    attr_reader :birth_place, :passport_expiration, :passport_issued, :state_id_type,
                :issuing_country_code, :nationality_code, :personal_number, :mrz

    def initialize(pii:)
      @pii_from_doc = pii
      @birth_place = pii[:birth_place]
      @passport_expiration = pii[:passport_expiration]
      @passport_issued = pii[:passport_issued]
      @state_id_type = pii[:state_id_type]
      @issuing_country_code = pii[:issuing_country_code]
      @nationality_code = pii[:nationality_code]
      @personal_number = pii[:personal_number]
      @mrz = pii[:mrz]
    end

    private

    attr_reader :pii_from_doc

    def generic_error
      I18n.t('doc_auth.errors.general.no_liveness')
    end
  end
end
