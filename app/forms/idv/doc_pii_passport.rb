# frozen_string_literal: true

module Idv
  class DocPiiPassport
    include ActiveModel::Model

    validates :birth_place,
              :passport_issued,
              :nationality_code,
              :mrz,
              presence: { message: proc { I18n.t('doc_auth.errors.general.no_liveness') } }

    validates :issuing_country_code,
              :nationality_code,
              inclusion: {
                in: 'USA', message: proc { I18n.t('doc_auth.errors.general.no_liveness') }
              }

    validate :passport_expired?

    attr_reader :birth_place, :passport_expiration, :passport_issued,
                :issuing_country_code, :nationality_code, :mrz

    def initialize(pii:)
      @pii_from_doc = pii
      @birth_place = pii[:birth_place]
      @passport_expiration = pii[:passport_expiration]
      @passport_issued = pii[:passport_issued]
      @issuing_country_code = pii[:issuing_country_code]
      @nationality_code = pii[:nationality_code]
      @mrz = pii[:mrz]
    end

    def self.pii_like_keypaths
      %i[birth_place passport_issued issuing_country_code nationality_code mrz]
    end

    private

    attr_reader :pii_from_doc

    def generic_error
      I18n.t('doc_auth.errors.general.no_liveness')
    end

    def passport_expired?
      if passport_expiration && DateParser.parse_legacy(passport_expiration).past?
        errors.add(:passport_expiration, generic_error, type: :passport_expiration)
      end
    end
  end
end
