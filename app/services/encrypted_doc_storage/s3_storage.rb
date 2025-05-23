# frozen_string_literal: true

module EncryptedDocStorage
  class S3Storage
    def write_image(encrypted_image:, name:)
      s3_client.put_object(
        bucket:,
        body: encrypted_image,
        key: name,
      )
    end

    private

    def s3_client
      Aws::S3::Client.new(
        http_open_timeout: 5,
        http_read_timeout: 5,
        compute_checksums: false,
      )
    end

    def bucket
      IdentityConfig.store.encrypted_document_storage_s3_bucket
    end
  end
end
