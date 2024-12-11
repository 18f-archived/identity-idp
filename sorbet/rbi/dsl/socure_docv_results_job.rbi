# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `SocureDocvResultsJob`.
# Please instead update this file by running `bin/tapioca dsl SocureDocvResultsJob`.


class SocureDocvResultsJob
  class << self
    sig do
      params(
        document_capture_session_uuid: T.untyped,
        async: T.untyped,
        docv_transaction_token_override: T.untyped,
        block: T.nilable(T.proc.params(job: SocureDocvResultsJob).void)
      ).returns(T.any(SocureDocvResultsJob, FalseClass))
    end
    def perform_later(document_capture_session_uuid:, async: T.unsafe(nil), docv_transaction_token_override: T.unsafe(nil), &block); end

    sig do
      params(
        document_capture_session_uuid: T.untyped,
        async: T.untyped,
        docv_transaction_token_override: T.untyped
      ).returns(T.untyped)
    end
    def perform_now(document_capture_session_uuid:, async: T.unsafe(nil), docv_transaction_token_override: T.unsafe(nil)); end
  end
end
