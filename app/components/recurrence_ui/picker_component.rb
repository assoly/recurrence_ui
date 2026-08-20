# app/components/recurrence_ui/picker_component.rb
module RecurrenceUi
  class PickerComponent < ViewComponent::Base
    attr_reader  :record, :field_name, :i18n_prefix, :identifier, :locale, :time_zone, :week_start
    def initialize(
      record:,
      form: nil,
      field_name: :recurring_rules,
      i18n_prefix: 'recurrence_ui',
      locale: nil,
      time_zone: nil,
      week_start: nil
    )
      @raw_form    = form
      @record      = record
      @field_name  = field_name
      @i18n_prefix = i18n_prefix
      @identifier  = "recurrence-ui"

      # Гем АВТОМАТИЧЕСКИ подтягивает актуальные отрезолвленные параметры из окружения/конфигов,
      # если они не перекрыты явными пропами выше.
      @locale     = RecurrenceUi.config.resolved_locale(locale)
      @time_zone  = RecurrenceUi.config.resolved_time_zone(time_zone)
      @week_start = RecurrenceUi.config.resolved_week_start(week_start)
    end
    
    # Если @raw_form равен nil, автоматически создаем виртуальный FormBuilder
    def form
      @form ||= @raw_form || ActionView::Helpers::FormBuilder.new(
        record_name,
        record,
        helpers,
        {}
      )
    end
    # Единая точка входа для данных. 
    # Безопасно парсит JSON или Hash и кэширует результат.
    def rules
      @rules ||= begin
        raw = @record.public_send(@field_name)
        # Важно: IceCube часто выдает символы, JSON.parse — строки. 
        # .with_indifferent_access обязателен для безопасности.
        parsed = raw.is_a?(String) ? (JSON.parse(raw) rescue {}) : raw
        (parsed || {}).with_indifferent_access
      end
    end

    # Добавляем метод, который потеряли! 
    # Именно его нужно рендерить в hidden_field в шаблоне.
    def rules_json
      rules.to_json
    end

    def current_rule_type
      # Если в базе лежит IceCube::DailyRule, превращаем в 'daily'
      raw_type = rules[:rule_type].to_s.demodulize.underscore.gsub('_rule', '')
      return 'never' if raw_type.blank? || raw_type == 'never'

      # Если это monthly/yearly, уточняем подтип для ваших новых вкладок
      if %w[monthly yearly].include?(raw_type)
        sub_type = validations[:day_of_week].present? ? 'by_weekday' : 'by_day_of_month'
        "#{raw_type}_#{sub_type}"
      else
        raw_type
      end
    end

    # Уточняем извлечение (IceCube хранит это внутри :validations)
    def validations           = rules[:validations] || {}
    def initial_interval      = rules[:interval] || 1
    def selected_weekly_days  = (validations[:day] || []).map(&:to_i)
    def selected_monthly_days = (validations[:day_of_month] || []).map(&:to_i)
    
    # Исправляем извлечение nth_days (в IceCube это Hash: { "1" => [1] })
    def selected_nth_days     = validations[:day_of_week] || {}

    def rule_options
      # Используем отвалидированную локаль компонента
      I18n.with_locale(@locale) do
        %w[never daily weekly monthly_by_day_of_month monthly_by_weekday yearly_by_day_of_month yearly_by_weekday].map do |type|
          [I18n.t("#{@i18n_prefix}.types.#{type}"), type]
        end
      end
    end

    
    def days_for_ui
      # @week_start возвращает 1 (Понедельник) или 0 (Воскресенье)
      shift = (@week_start == 1) ? 1 : 0
      (0..6).to_a.rotate(shift)
    end

    def months_for_ui
      I18n.with_locale(@locale) do
        (1..12).map { |m| [I18n.t("#{@i18n_prefix}.date.month_names", default: I18n.t('date.month_names'))[m], m] }
      end
    end

    def nth_weeks
      I18n.with_locale(@locale) do
        [1, 2, 3, 4, 5, -1].map do |n| 
          label = if n == -1
            I18n.t("#{@i18n_prefix}.last", default: "last")
          else
            I18n.t("#{@i18n_prefix}.nth_weeks.#{n}", default: "#{n}th")
          end
          [n, label]
        end
      end
    end
    # Метод генерации текстового описания
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
    def identifier
      "recurrence-ui" # Оставляем для Stimulus
    end
    private
    def record_name
      record.respond_to?(:model_name) ? record.model_name.param_key : :record
    end
  end
end