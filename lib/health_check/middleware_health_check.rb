module HealthCheck
  class MiddlewareHealthcheck

    def initialize(app)
      @app = app
    end

    def call(env)
      uri = env['PATH_INFO']
      if uri =~ /^\/?#{HealthCheck.uri_middleware}(\/([-_0-9a-zA-Z]*))?(\.(\w*))?$/
        checks = $2 || 'standard'
        response_type = $4 || 'plain'
        puts checks
        begin
          errors = HealthCheck::Utils.process_checks(checks)
        rescue => e
          errors = e.message.blank? ? e.class.to_s : e.message.to_s
        end
        healthy = errors.blank?
        msg = healthy ? HealthCheck.success : "health_check failed: #{errors}"
        if response_type == 'xml'
          content_type = 'text/xml'
          msg = { healthy: healthy, message: msg }.to_xml
        elsif response_type == 'json'
          content_type = 'application/json'
          msg = { healthy: healthy, message: msg }.to_json
        elsif response_type == 'plain'
          content_type = 'text/plain'
        end
        [ (healthy ? 200 : 500), { 'Content-Type' => content_type }, [msg] ]
      else
        @app.call(env)
      end
    end

  end
end
