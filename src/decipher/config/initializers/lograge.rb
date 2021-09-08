# frozen_string_literal: true

require 'json/add/exception'

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.base_controller_class = ['ActionController::API', 'ActionController::Base']
  config.lograge.formatter = Lograge::Formatters::Json.new

  def add_rescued_exception(opts, exc)
    return unless exc

    opts[:rescued_exception] = {
      name: exc.class.name,
      message: exc.message,
      backtrace: %('#{Array(exc.backtrace.first(10)).join("\n\t")}')
    }
  end

  config.lograge.custom_options = lambda do |event|
    # puts event.payload.to_json

    # Additional fields to be logged to LogDNA
    exceptions = %w[controller action format]
    ret = {
      application: Rails.application.class,
      host: event.payload[:host],
      rails_env: Rails.env,

      process_id: Process.pid,
      request_id: event.payload[:headers]['action_dispatch.request_id'],
      request_time: Time.now,

      remote_ip: event.payload[:remote_ip],
      ip: event.payload[:ip],
      x_forwarded_for: event.payload[:x_forwarded_for],

      params: event.payload[:params].except(*exceptions)
    }

    if (eo = event.payload[:exception_object])
      ret.merge!({ 'error_message' => eo.message })
      ret.merge!({ 'error_stacktrace' => eo.backtace[0..3].join(',').to_json })
    end
    ret
  end
end
