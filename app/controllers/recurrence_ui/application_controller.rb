# app/controllers/recurrence_ui/application_controller.rb
module RecurrenceUi
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    around_action :with_recurrence_context

    private

    def with_recurrence_context(&action)
      # Resolve the locale, time zone, and week start based on the provided params or defaults
      resolved_locale     = RecurrenceUi.config.resolved_locale(params[:locale])
      resolved_time_zone  = RecurrenceUi.config.resolved_time_zone(params[:time_zone])
      
      raw_week_start      = RecurrenceUi.config.resolved_week_start(params[:week_start])
      resolved_week_start = (raw_week_start == 1) ? :monday : :sunday

      # Force the environment to the time of HTTP request execution
      I18n.with_locale(resolved_locale) do
        Time.use_zone(resolved_time_zone) do
          old_week_start = Date.beginning_of_week
          Date.beginning_of_week = resolved_week_start
          begin
            action.call
          ensure
            Date.beginning_of_week = old_week_start
          end
        end
      end
    end
  end
end