module HealthCheck
  class MiddlewareHealthcheck

    def initialize(app)
      @app = app
    end

    def call(env)
      uri = env['PATH_INFO'.freeze]
      if uri.include? HealthCheck.uri
        response_type = uri.sub! '/' + HealthCheck.uri + '.' , ''
        response_method = 'response_' + response_type.to_s
        checks = 'standard'
        begin
          errors = HealthCheck::Utils.process_checks(checks)
        rescue Exception => e
          errors = e.message.blank? ? e.class.to_s : e.message.to_s
        end
        if errors.blank?
          return send(response_method, 200, HealthCheck.success, true)
        else
          msg = "health_check failed: #{errors}"
          return send(response_method, 500, msg, false)
        end
      else
        @app.call(env)
      end
    end

    def response_json code, msg, healthy
      obj = { healthy: healthy, message: msg }
      return [ code, { 'Content-Type' => 'application/json' }, [obj.to_json] ]
    end
    def response_xml code, msg, healthy
      obj = { healthy: healthy, message: msg }
      return [ code, { 'Content-Type' => 'text/xml' }, [obj.to_xml] ]
    end
    def response_ code, msg, healthy
      return [ code, { 'Content-Type' => 'text/plain' }, [msg] ]
    end
  end
end
