# Copyright (c) 2010-2013 Ian Heggie, released under the MIT license.
# See MIT-LICENSE for details.

module HealthCheck
  class HealthCheckController < ActionController::Base

    layout false if self.respond_to? :layout
    before_filter :authenticate

    def index
      checks = params[:checks] || 'standard'
      begin
        errors = HealthCheck::Utils.process_checks(checks)
      rescue Exception => e
        errors = e.message.blank? ? e.class.to_s : e.message.to_s
      end     
      # Rails 4.0 doesn't have :plain, but it is deprecated later on
      plain_key = Rails.version < '4.1' ? :text : :plain
      if errors.blank?
        response.headers['Last-Modified'] = Time.now.httpdate
        obj = { :healthy => true, :message => HealthCheck.success }
        respond_to do |format|
          format.html { render plain_key => HealthCheck.success, :content_type => 'text/plain' }
          format.json { render :json => obj }
          format.xml { render :xml => obj }
          format.any { render plain_key => HealthCheck.success, :content_type => 'text/plain' }
        end
      else
        msg = "health_check failed: #{errors}"
        obj = { :healthy => false, :message => msg }
        respond_to do |format|
          format.html { render plain_key => msg, :status => HealthCheck.http_status_for_error_text, :content_type => 'text/plain' }
          format.json { render :json => obj, :status => HealthCheck.http_status_for_error_object}
          format.xml { render :xml => obj, :status => HealthCheck.http_status_for_error_object }
          format.any { render plain_key => msg, :status => HealthCheck.http_status_for_error_text, :content_type => 'text/plain' }
        end
        # Log a single line as some uptime checkers only record that it failed, not the text returned
        if logger
          logger.info msg
        end
      end
    end


    protected

    def authenticate
      return unless HealthCheck.basic_auth_username && HealthCheck.basic_auth_password
      authenticate_or_request_with_http_basic do |username, password|
        username == HealthCheck.basic_auth_username && password == HealthCheck.basic_auth_password
      end
    end

    # turn cookies for CSRF off
    def protect_against_forgery?
      false
    end

  end
end
