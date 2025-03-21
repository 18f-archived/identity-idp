# frozen_string_literal: true

module Encryption
  class MultiRegionKmsProfileMigrator
    include ::NewRelic::Agent::MethodTracer

    attr_reader :profile

    def initialize(profile)
      @profile = profile
    end

    def migrate!
      profile.with_lock do
        if profile.encrypted_pii.blank? && profile.encrypted_pii_recovery.blank?
          raise "Profile##{profile.id} is missing encrypted_pii or encrypted_pii_recovery"
        end

        next if profile.encrypted_pii_multi_region.present? &&
                profile.encrypted_pii_recovery_multi_region.present?

        if profile.encrypted_pii.present? && profile.encrypted_pii_multi_region.blank?
          encrypted_pii_multi_region = migrate_ciphertext(profile.encrypted_pii)
          profile.update!(
            encrypted_pii_multi_region: encrypted_pii_multi_region,
          )
        end
        if profile.encrypted_pii_recovery.present? &&
           profile.encrypted_pii_recovery_multi_region.blank?
          encrypted_pii_recovery_multi_region = migrate_ciphertext(profile.encrypted_pii_recovery)
          profile.update!(
            encrypted_pii_recovery_multi_region: encrypted_pii_recovery_multi_region,
          )
        end

        profile
      end
    end

    private

    def migrate_ciphertext(ciphertext_string)
      ciphertext = Encryption::Encryptors::PiiEncryptor::Ciphertext.parse_from_string(
        ciphertext_string,
      )

      aes_encrypted_data = multi_region_kms_client.decrypt(
        ciphertext.encrypted_data, kms_encryption_context
      )
      multi_region_kms_encrypted_data = multi_region_kms_client.encrypt(
        aes_encrypted_data, kms_encryption_context
      )
      Encryption::Encryptors::PiiEncryptor::Ciphertext.new(
        multi_region_kms_encrypted_data,
        ciphertext.salt,
        ciphertext.cost,
      )
    end

    def kms_encryption_context
      {
        'context' => 'pii-encryption',
        'user_uuid' => profile.user.uuid,
      }
    end

    def multi_region_kms_client
      @multi_region_kms_client ||= KmsClient.new(
        kms_key_id: IdentityConfig.store.aws_kms_multi_region_key_id,
      )
    end
  end
end
