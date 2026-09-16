# app/helpers/recurrence_ui/application_helper.rb
module RecurrenceUi
  module ApplicationHelper
    def recurrence_ui_tag(options = {})
      # Ensure that the locale is set to the current locale if not provided in options
      # This is important for the translations to work correctly, especially when the locale is changed dynamically in the application.
      # Priority: local options -> gem config -> defaults
      locale     = options[:locale] || RecurrenceUi.config.resolved_locale
      time_zone  = options[:time_zone] || RecurrenceUi.config.resolved_time_zone
      week_start = options[:week_start] || RecurrenceUi.config.resolved_week_start

      content_tag :div,
        "",
        data: {
          controller: "recurrence-ui",
          "recurrence-ui-locale-value": locale,
          "recurrence-ui-time-zone-value": time_zone,
          "recurrence-ui-week-start-value": week_start,
          "recurrence-ui-translations-value": I18n.t("recurrence_ui", locale: locale).to_json
        }
    end
  end
end