# app/components/recurrence_ui/picker_component.rb
module RecurrenceUi
  class PickerComponent < ViewComponent::Base
    attr_reader :record, :field_name, :i18n_prefix, :identifier, :locale, :time_zone, :week_start, :enabled_rule_types

    def initialize(
      record:,
      form: nil,
      field_name: :recurring_rules,
      i18n_prefix: 'recurrence_ui',
      locale: nil,
      time_zone: nil,
      week_start: nil,
      enabled_rule_types: nil
    )
      @raw_form    = form
      @record      = record
      @field_name  = field_name
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

    def form
      @form ||= @raw_form || ActionView::Helpers::FormBuilder.new(
        record_name,
        record,
        helpers,
        {}
      )
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

      RecurrenceUi::RecurrenceSummaryService.new(
        rule_hash,
        locale: locale,
        time_zone: time_zone,
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