  
# frozen_string_literal: true

return unless ENV.fetch("APPLY_CONFIG_FOR_RDS_PROXY", "true") == "true"

Encoding.default_internal = nil # for pg version >= 1.5.4 it's not necessary

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  private

  def exec_no_cache(sql, name, binds, async: false)
    materialize_transactions
    mark_transaction_written_if_write(sql)

    # make sure we carry over any changes to ActiveRecord.default_timezone that have been
    # made since we established the connection
    update_typemap_for_default_timezone

    type_casted_binds = type_casted_binds(binds)
    log(sql, name, binds, type_casted_binds, async:) do
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        # -- monkeypatch --
        # to use async_exec instead of exec_params if prepared statements are disabled

        if ActiveRecord::Base.connection_db_config.configuration_hash.fetch(:prepared_statements, "true").to_s == "true"
          Retryable.perform(times: 3, errors: [PG::ConnectionBad, PG::ConnectionException], before_retry: ->(_) { reconnect! }) do
            @connection.exec_params(sql, type_casted_binds)
          end
        else
          Retryable.perform(times: 3, errors: [PG::ConnectionBad, PG::ConnectionException], before_retry: ->(_) { reconnect! }) do
            @connection.exec(sql)
          end
        end
        # -- end of monkeypatch --
      end
    end
  end

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
