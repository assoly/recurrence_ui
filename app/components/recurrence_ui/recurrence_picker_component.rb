# app/components/recurrence_ui/recurrence_picker_component.rb
module RecurrenceUi
  class RecurrencePickerComponent < ViewComponent::Base
    attr_reader :record, :i18n_prefix, :identifier, :locale, :time_zone, :week_start, :enabled_rule_types

    def initialize(
      record:,
      form: nil,
      i18n_prefix: 'recurrence_ui',
      locale: nil,
      time_zone: nil,
      week_start: nil,
      enabled_rule_types: nil
    )
      @raw_form    = form
      @record      = record
      @i18n_prefix = i18n_prefix
      @identifier  = "recurrence-ui"

      # Resolve enabled_rule_types considering allowed values and order preservation
      @enabled_rule_types = RecurrenceUi.config.resolved_enabled_rule_types(enabled_rule_types)

      # Resolve environment configuration fallbacks
      @locale     = RecurrenceUi.config.resolved_locale(locale)
      @time_zone  = RecurrenceUi.config.resolved_time_zone(time_zone)
      @week_start = RecurrenceUi.config.resolved_week_start(week_start)

      log_configuration_details if Rails.env.development?
    end
    def field_name
      @field_name ||= if record.class.respond_to?(:recurrence_rules_field)
        record.class.recurrence_rules_field
      else
        RecurrenceUi.config.default_recurring_rules_field
      end
    end
    def form
      @form ||= @raw_form || ActionView::Helpers::FormBuilder.new(
        record_name,
        record,
        helpers,
        {}
      )
    end
    # --- Динамические хелперы для вычисления начальных значений длительности ---
    # Вычисляет количество дней длительности из записи
    def initial_form_duration_days
      dur = record.public_send(duration_field).to_i
      return 0 if dur <= 0
      (dur / 1.day).to_i
    end

    # Вычисляет оставшиеся часы длительности
    def initial_form_duration_hours
      dur = record.public_send(duration_field).to_i
      return 1 if dur <= 0 # дефолтное значение, если пусто
      ((dur % 1.day) / 1.hour).to_i
    end

    # Вычисляет оставшиеся минуты длительности
    def initial_form_duration_minutes
      dur = record.public_send(duration_field).to_i
      return 0 if dur <= 0
      ((dur % 1.hour) / 1.minute).to_i
    end

    # Определяет, какая радиокнопка должна быть выбрана при открытии формы (:duration или :end_at)
    def initial_form_duration_mode
      saved_mode = rules[:form_duration_mode]
      return saved_mode.to_sym if saved_mode.present?

      :duration # дефолт
    end
    
    
    # --- Динамические хелперы для имён полей из модели ---

    def start_time_field
      @start_time_field ||= record.class.respond_to?(:recurrence_start_time_field) ? record.class.recurrence_start_time_field : :start_at
    end

    def end_time_field
      @end_time_field ||= record.class.respond_to?(:recurrence_end_time_field) ? record.class.recurrence_end_time_field : :end_at
    end
    # Возвращает начало события в часовом поясе самого события.
    def initial_start_at
      value = record.public_send(start_time_field)
      return if value.blank?

      value.in_time_zone(event_time_zone)
    end

    # Возвращает окончание события в часовом поясе самого события.
    def initial_end_at
      value = record.public_send(end_time_field)
      return if value.blank?

      value.in_time_zone(event_time_zone)
    end

    # Определяет часовой пояс события.
    def event_time_zone
      if record.respond_to?(:event_time_zone)
        record.event_time_zone
      else
        zone_name = record.public_send(time_zone_field) if
          record.respond_to?(time_zone_field)

        ActiveSupport::TimeZone[zone_name.presence] ||
          ActiveSupport::TimeZone[Rails.application.config.time_zone]
      end
    end
    def duration_field
      @duration_field ||= record.class.respond_to?(:recurrence_duration_field) ? record.class.recurrence_duration_field : :duration
    end
    def time_zone_field
      @time_zone_field ||= record.class.respond_to?(:recurrence_time_zone_field) ? record.class.recurrence_time_zone_field : :time_zone
    end

    def rules
      @rules ||= begin
        raw = record.public_send(field_name)
        parsed = raw.is_a?(String) ? (JSON.parse(raw) rescue {}) : raw
        (parsed || {}).with_indifferent_access
      end
    end

    def rules_json
      rules.to_json
    end

    def current_rule_type
      raw_type = rules[:rule_type].to_s.demodulize.underscore.gsub('_rule', '')
      return 'never' if raw_type.blank? || raw_type == 'never'

      if %w[monthly yearly].include?(raw_type)
        sub_type = validations[:day_of_week].present? ? 'by_weekday' : 'by_day_of_month'
        "#{raw_type}_#{sub_type}"
      else
        raw_type
      end
    end

    def validations           = rules[:validations] || {}
    def initial_interval      = rules[:interval] || 1
    def selected_weekly_days  = (validations[:day] || []).map(&:to_i)
    def selected_monthly_days = (validations[:day_of_month] || []).map(&:to_i)
    def selected_nth_days     = validations[:day_of_week] || {}

    # Uses the pre-resolved @enabled_rule_types directly without re-resolving
    def rule_options
      enabled_rule_types.reject { |type| type == 'never' }.map do |type|
        [I18n.t("#{i18n_prefix}.types.#{type}", locale: locale), type]
      end
    end

    def days_for_ui
      shift = (week_start == 1) ? 1 : 0
      (0..6).to_a.rotate(shift)
    end

    def months_for_ui
      I18n.with_locale(locale) do
        (1..12).map { |m| [I18n.t("#{i18n_prefix}.date.month_names", default:  I18n.t("recurrence_ui.date.month_names"))[m], m] }
      end
    end

    def nth_weeks
      I18n.with_locale(locale) do
        [1, 2, 3, 4, 5, -1].map do |n| 
          label = if n == -1
            I18n.t("#{i18n_prefix}.last", default: "last")
          else
            I18n.t("#{i18n_prefix}.nth_weeks.#{n}", default: "#{n}th")
          end
          [n, label]
        end
      end
    end

    def recurrence_summary
      rule_hash = rules
      return "" if rule_hash.blank?

      RecurrenceUi::RecurrenceFormatterService.new(
        rule_hash,
        locale: locale,
        time_zone: event_time_zone,
        week_start: week_start
      ).to_s
    end

    private

    def record_name
      record.respond_to?(:model_name) ? record.model_name.param_key : :record
    end

    def log_configuration_details
      Rails.logger.debug("[RecurrenceUi] Locale: #{locale} | TimeZone: #{time_zone} | WeekStart: #{week_start}")
    end
  end
end