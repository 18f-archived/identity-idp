# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Reports::SpActiveUsersReport`.
# Please instead update this file by running `bin/tapioca dsl Reports::SpActiveUsersReport`.


class Reports::SpActiveUsersReport
  class << self
    sig do
      params(
        date: T.untyped,
        block: T.nilable(T.proc.params(job: Reports::SpActiveUsersReport).void)
      ).returns(T.any(Reports::SpActiveUsersReport, FalseClass))
    end
    def perform_later(date, &block); end

    sig { params(date: T.untyped).returns(T.untyped) }
    def perform_now(date); end
  end
end
