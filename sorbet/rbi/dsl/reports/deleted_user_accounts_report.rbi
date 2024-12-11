# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Reports::DeletedUserAccountsReport`.
# Please instead update this file by running `bin/tapioca dsl Reports::DeletedUserAccountsReport`.


class Reports::DeletedUserAccountsReport
  class << self
    sig do
      params(
        _date: T.untyped,
        block: T.nilable(T.proc.params(job: Reports::DeletedUserAccountsReport).void)
      ).returns(T.any(Reports::DeletedUserAccountsReport, FalseClass))
    end
    def perform_later(_date, &block); end

    sig { params(_date: T.untyped).returns(T.untyped) }
    def perform_now(_date); end
  end
end
