# frozen_string_literal: true

module Idv
  class DuplicateSsnFinder
    attr_reader :ssn, :user

    def initialize(user:, ssn:)
      @user = user
      @ssn = ssn
    end

    def ssn_is_unique?
      Profile.where.not(user_id: user.id).where(ssn_signature: ssn_signatures).empty?
    end

    def ssn_signatures
      formatted_ssn = SsnFormatter.format(ssn)
      normalized_ssn = SsnFormatter.normalize(ssn)
      ssns = [formatted_ssn, normalized_ssn]

      keys = [Pii::Fingerprinter.current_key] + IdentityConfig.store.hmac_fingerprinter_key_queue
      keys.flat_map do |key|
        ssns.map do |ssn|
          Pii::Fingerprinter.fingerprint(ssn, key)
        end
      end
    end
  end
end
