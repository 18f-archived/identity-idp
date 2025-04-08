  
# frozen_string_literal: true

return unless ENV.fetch("APPLY_CONFIG_FOR_RDS_PROXY", "false") == "true"

Encoding.default_internal = nil # for pg version >= 1.5.4 it's not necessary

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  protected

  def configure_connection
    # if @config[:encoding]
    #   @connection.set_client_encoding(@config[:encoding])
    # end
    # self.client_min_messages = @config[:min_messages] || "warning"
    self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]
    #
    # # Use standard-conforming strings so we don't have to do the E'...' dance.
    # set_standard_conforming_strings
    #
    # variables = @config.fetch(:variables, {}).stringify_keys
    #
    # # If using Active Record's time zone support configure the connection to return
    # # TIMESTAMP WITH ZONE types in UTC.
    # unless variables["timezone"]
    #   if ActiveRecord::Base.default_timezone == :utc
    #     variables["timezone"] = "UTC"
    #   elsif @local_tz
    #     variables["timezone"] = @local_tz
    #   end
    # end
    #
    # # Set interval output format to ISO 8601 for ease of parsing by ActiveSupport::Duration.parse
    # execute("SET intervalstyle = iso_8601", "SCHEMA")
    #
    # # SET statements from :variables config hash
    # # https://www.postgresql.org/docs/current/static/sql-set.html
    # variables.map do |k, v|
    #   if v == ":default" || v == :default
    #     # Sets the value to the global or compile default
    #     execute("SET SESSION #{k} TO DEFAULT", "SCHEMA")
    #   elsif !v.nil?
    #     execute("SET SESSION #{k} TO #{quote(v)}", "SCHEMA")
    #   end
    # end
  end
end