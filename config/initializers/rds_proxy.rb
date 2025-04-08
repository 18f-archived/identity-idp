  
# frozen_string_literal: true

return unless ENV.fetch("APPLY_CONFIG_FOR_RDS_PROXY", "false") == "true"

Encoding.default_internal = nil # for pg version >= 1.5.4 it's not necessary

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter

  private
    # Configures the encoding, verbosity, schema search path, and time zone of the connection.
    # This is called by #connect and should not be called manually.
    def configure_connection
        # super

        # if @config[:encoding]
        #   @raw_connection.set_client_encoding(@config[:encoding])
        # end
        # self.client_min_messages = @config[:min_messages] || "warning"
        self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

        # unless ActiveRecord.db_warnings_action.nil?
        #     @raw_connection.set_notice_receiver do |result|
        #       message = result.error_field(PG::Result::PG_DIAG_MESSAGE_PRIMARY)
        #       code = result.error_field(PG::Result::PG_DIAG_SQLSTATE)
        #       level = result.error_field(PG::Result::PG_DIAG_SEVERITY)
        #       @notice_receiver_sql_warnings << SQLWarning.new(message, code, level, nil, @pool)
        #     end
        #   end

        # Use standard-conforming strings so we don't have to do the E'...' dance.
        # set_standard_conforming_strings

        # variables = @config.fetch(:variables, {}).stringify_keys

        # Set interval output format to ISO 8601 for ease of parsing by ActiveSupport::Duration.parse
        # internal_execute("SET intervalstyle = iso_8601", "SCHEMA")

        # SET statements from :variables config hash
        # https://www.postgresql.org/docs/current/static/sql-set.html
        # variables.map do |k, v|
            # if v == ":default" || v == :default
            #     # Sets the value to the global or compile default
            #     internal_execute("SET SESSION #{k} TO DEFAULT", "SCHEMA")
            # elsif !v.nil?
            #     internal_execute("SET SESSION #{k} TO #{quote(v)}", "SCHEMA")
            # end
        # end

        # add_pg_encoders
        # add_pg_decoders

        # reload_type_map
    end
end