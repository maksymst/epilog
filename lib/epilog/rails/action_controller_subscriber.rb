# frozen_string_literal: true

# rubocop:disable ClassLength
module Epilog
  module Rails
    class ActionControllerSubscriber < LogSubscriber
      RAILS_PARAMS = %i[controller action format _method only_path].freeze

      def request_received(event)
        info do
          {
            message: "#{request_string(event)} started",
            request: request_hash(event)
          }
        end
      end

      def process_request(event)
        info do
          event.payload[:context].merge(
            message: response_string(event),
            request: short_request_hash(event),
            response: response_hash(event),
            metrics: process_metrics(event.payload[:metrics]
              .merge(request_runtime: event.duration.round(2)))
          )
        end
      end

      def start_processing(*)
      end

      def process_action(*)
      end

      def send_data(event)
        info { basic_message(event, "Sent data #{event.payload[:filename]}") }
      end

      def send_file(event)
        info { basic_message(event, "Sent file #{event.payload[:path]}") }
      end

      def redirect_to(event)
        info { basic_message(event, "Redirect > #{event.payload[:location]}") }
      end

      def halted_callback(event)
        info do
          basic_message(event, 'Filter chain halted as ' \
            "#{event.payload[:filter].inspect} rendered or redirected")
        end
      end

      def unpermitted_parameters(event)
        debug do
          basic_message(event, 'Unpermitted parameters: ' \
            "#{event.payload[:keys].join(', ')}")
        end
      end

      %i[
        write_fragment
        read_fragment
        exist_fragment?
        expire_fragment
        expire_page
        write_page
      ].each do |method|
        define_method(method) do |event|
          return unless logger.info?

          path = Array(event.payload[:key] || event.payload[:path]).join('/')
          debug(basic_message(event, "#{method} #{path}"))
        end
      end

      private

      def request_hash(event) # rubocop:disable AbcSize, MethodLength
        request = event.payload[:request]
        {
          id: request.uuid,
          ip: request.remote_ip,
          host: request.host,
          protocol: request.protocol.to_s.gsub('://', ''),
          method: request.request_method,
          port: request.port,
          path: request.fullpath,
          query: request.query_parameters,
          cookies: request.cookies,
          headers: request.headers.to_h.keep_if do |key, _value|
            key =~ ActionDispatch::Http::Headers::HTTP_HEADER
          end,
          params: request.filtered_parameters.except(*RAILS_PARAMS),
          format: request.format.try(:ref),
          controller: event.payload[:controller],
          action: event.payload[:action]
        }
      end

      def short_request_hash(event)
        request = event.payload[:request]
        {
          id: request.uuid,
          method: request.method,
          path: request.fullpath
        }
      end

      def request_string(event)
        request = event.payload[:request]
        "#{request.request_method} #{request.fullpath}"
      end

      def response_hash(event)
        { status: normalize_status(event) }
      end

      def response_string(event)
        status = normalize_status(event)
        status_string = Rack::Utils::HTTP_STATUS_CODES[status]
        "#{request_string(event)} > #{status} #{status_string}"
      end

      def normalize_status(event)
        payload = event.payload
        status = payload[:response].status
        if status.nil? && payload[:exception].present?
          status = ActionDispatch::ExceptionWrapper
            .status_code_for_exception(payload[:exception].first)
        end
        status
      end

      def basic_message(event, message)
        {
          message: message,
          metrics: process_metrics(duration: event.duration)
        }
      end

      def process_metrics(metrics)
        metrics.each_with_object({}) do |(key, value), obj|
          next if value.nil?

          obj[key] = value.round(2) if value.is_a?(Numeric)
        end
      end
    end
  end
end
# rubocop:enable ClassLength
