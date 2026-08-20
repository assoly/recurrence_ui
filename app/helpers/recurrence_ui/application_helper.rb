# app/helpers/recurrence_ui/application_helper.rb
module RecurrenceUi
  module ApplicationHelper
    def recurrence_ui_tag(options = {})
      # Разрешаем конфиги с тем же приоритетом: локальные options -> конфиг гема -> дефолты
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