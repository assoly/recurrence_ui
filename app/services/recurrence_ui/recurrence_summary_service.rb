# app/services/recurrence_summary_service.rb
module RecurrenceUi
  class RecurrenceSummaryService
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper

    DAY_SYMBOL_TO_INDEX = {
      sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
      sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6
    }.freeze

    attr_reader :event, :schedule, :locale, :time_zone, :week_start

    # Поддерживает как передачу целиком event/record, так и schedule_hash
    def initialize(target_or_hash, options = {})
      if target_or_hash.respond_to?(:recurrence_raw_rules) || target_or_hash.is_a?(ActiveRecord::Base)
        @event = target_or_hash
        @schedule = (@event.recurrence_raw_rules || {}).with_indifferent_access.except(:form_duration_mode, 'form_duration_mode')
      else
        @event = nil
        @schedule = (target_or_hash || {}).with_indifferent_access.except(:form_duration_mode, 'form_duration_mode')
      end

      # 1. Configuration resolution
      @locale     = resolve_locale(options[:locale])
      # Приоритет таймзоны: из опций -> из модели @event -> из конфига
      @time_zone  = resolve_time_zone(options[:time_zone] || (@event.respond_to?(:event_time_zone) ? @event.event_time_zone : nil))
      @week_start = resolve_week_start(options[:week_start])

      raw_rrules = @schedule[:rrules]
      @rrules = if raw_rrules.is_a?(Array)
                  raw_rrules
                elsif @schedule[:rule_type].present?
                  [@schedule]
                else
                  []
                end
    end

    # --- Основной вывод текстового правила повторения ---
    def to_s
      main_text = if @rrules.present?
                    @rrules.map { |rule_hash| SingleRuleSummary.new(rule_hash, @locale).to_s }.join("; ")
                  else
                    I18n.t("recurrence_ui.one_time", locale: @locale, default: "Once")
                  end

      exceptions_text = format_exceptions
      rdates_text = format_rdates
      main_html = tag.span(main_text, class: "rui-meta-info rui-meta-info--main")
      "#{main_html}#{exceptions_text}#{rdates_text}".strip.html_safe
    end

    # --- НОВЫЕ МЕТОДЫ ФОРМАТИРОВАНИЯ ---

    # Форматирование времени начала события
    # zone_type: :event, :application (или передача строки зоны)
    def start_time(zone_type = :application, format = :default, show_zone: false)
      return "—" unless @event

      target_zone = resolve_zone_type(zone_type)
      time = @event.start_time_in_zone(target_zone)
      return "—" unless time

      formatted = I18n.l(time, format: format, locale: @locale)
      show_zone ? "#{formatted} (#{time.strftime('%Z')})" : formatted
    end

    # Форматирование времени окончания события
    def end_time(zone_type = :application, format = :default, show_zone: false)
      return "—" unless @event

      target_zone = resolve_zone_type(zone_type)
      time = @event.end_time_in_zone(target_zone)
      return "—" unless time

      formatted = I18n.l(time, format: format, locale: @locale)
      show_zone ? "#{formatted} (#{time.strftime('%Z')})" : formatted
    end

    # Форматированная длительность
    def duration
      return "—" unless @event
      @event.formatted_duration
    end

    # Форматированные ближайшие повторения
    def upcoming_occurrences(limit = 5, zone_type = :application, format = :default, show_zone: false)
      return [] unless @event

      target_zone = resolve_zone_type(zone_type)
      occurrences = @event.upcoming_occurrences(limit, target_zone)

      occurrences.map do |occ|
        start_str = I18n.l(occ.start_time, format: format, locale: @locale)
        end_str   = occ.end_time ? I18n.l(occ.end_time, format: format, locale: @locale) : nil

        if show_zone
          start_str += " (#{occ.start_time.strftime('%Z')})"
          end_str   += " (#{occ.end_time.strftime('%Z')})" if end_str
        end

        { start_time: start_str, end_time: end_str }
      end
    end

    # Форматирование произвольной даты (статистический метод)
    def self.format_date(date_or_string, locale, show_time_zone: false, time_zone: nil)
      return '' if date_or_string.blank?

      date = date_or_string.is_a?(String) ? Date.parse(date_or_string) : date_or_string

      format_pattern = I18n.t("recurrence_ui.date.formats.recurrence_date", locale: locale, default: "%-d %B %Y")
      month_names = I18n.t("recurrence_ui.date.month_names", locale: locale, default: Date::MONTHNAMES)
      month_name = month_names[date.month] || ""

      formatted = format_pattern
        .gsub("%Y", date.year.to_s)
        .gsub("%-m", date.month.to_s)
        .gsub("%m", date.month.to_s.rjust(2, '0'))
        .gsub("%-d", date.day.to_s)
        .gsub("%d", date.day.to_s.rjust(2, '0'))
        .gsub("%B", month_name)

      if show_time_zone && time_zone.present?
        tz = time_zone.is_a?(ActiveSupport::TimeZone) ? time_zone : Time.find_zone(time_zone)
        formatted += " (#{tz&.formatted_offset || tz.to_s})"
      end

      formatted
    end

    private

    def resolve_zone_type(zone_type)
      case zone_type
      when :event
        @event.event_time_zone
      when :application, :app
        Time.zone
      else
        Time.find_zone(zone_type) || Time.zone
      end
    end

    def resolve_locale(passed_locale)
      passed_locale || RecurrenceUi.config.resolved_locale
    end

    def resolve_time_zone(passed_tz)
      passed_tz || RecurrenceUi.config.resolved_time_zone
    end

    def resolve_week_start(passed_ws)
      return passed_ws.to_i if passed_ws.present?
      RecurrenceUi.config.resolved_week_start
    end

    def format_exceptions
      return "" if @schedule[:exdates].blank?

      except_label = I18n.t("recurrence_ui.labels.exceptions", locale: @locale, default: "Except")
      formatted_dates = @schedule[:exdates].map { |d| self.class.format_date(d, @locale) }
      dates_str = formatted_dates.join(", ")

      tag.span("#{except_label}: #{dates_str}", class: "rui-meta-info rui-meta-info--exceptions")
    end

    def format_rdates
      return "" if @schedule[:rdates].blank?

      rdate_label = I18n.t("recurrence_ui.labels.rdates", locale: @locale, default: "Also on")
      formatted_dates = @schedule[:rdates].map { |d| self.class.format_date(d, @locale) }
      dates_str = formatted_dates.join(", ")

      tag.span("#{rdate_label}: #{dates_str}", class: "rui-meta-info rui-meta-info--rdates")
    end

    # --- Вложенный класс SingleRuleSummary остается без изменений ---
  end

  # Альтернативный класс-псевдоним (алиас), если хотите использовать имя EventSummaryService
end