# lib/recurrence_ui/configuration.rb
module RecurrenceUi
  class Configuration
    
    SUPPORTED_LOCALES = %w[en ru ja].freeze # Локали, для которых есть yml-файлы в геме
    DEFAULT_LOCALE = 'en'.freeze
    DEFAULT_TIME_ZONE = 'UTC'.freeze
    DEFAULT_WEEK_START = 0
    ALL_RULE_TYPES = %w[
          never
          daily
          weekly
          monthly_by_day_of_month
          monthly_by_weekday
          yearly_by_day_of_month
          yearly_by_weekday
        ].freeze

    attr_accessor :enabled_rule_types, :locale, :time_zone, :week_start, :supported_locales

    def initialize
      @locale = nil
      @time_zone = nil
      @week_start = nil
      @supported_locales = SUPPORTED_LOCALES
      @enabled_rule_types = ALL_RULE_TYPES.dup
    end

    def resolved_locale(requested = nil)
      # 1. Собираем кандидатную локаль
      # Приоритет: requested -> I18n.locale -> @locale
      candidate = requested&.to_s.presence ||
                  (defined?(I18n) && I18n.locale&.to_s.presence) ||
                  @locale&.to_s.presence

      # 2. Валидируем против поддерживаемых гемом
      if SUPPORTED_LOCALES.include?(candidate)
        candidate
      else
        # Необязательно: Логируем предупреждение в dev-режиме, если пришел :fr
        log_unsupported_locale_warning(candidate) if candidate.present?
        
        DEFAULT_LOCALE
      end
    end

    def resolved_time_zone(requested = nil)
      # Приоритет: requested -> Time.zone -> @time_zone
      candidate = requested.presence ||
                  (defined?(Time) && Time.respond_to?(:zone) && Time.zone&.name.presence) ||
                  @time_zone.presence
        # Проверяем, существует ли такой часовой пояс в Rails
        if candidate.present? && defined?(ActiveSupport::TimeZone) && ActiveSupport::TimeZone[candidate].present?
            candidate
        else
            DEFAULT_TIME_ZONE
        end
    end

    def resolved_week_start(requested = nil)
      # Приоритет: requested -> Date.beginning_of_week -> @week_start
      rails_week_start = defined?(Date) && Date.respond_to?(:beginning_of_week) ? (Date.beginning_of_week == :monday ? 1 : 0) : nil

      raw = requested.presence ||
            rails_week_start ||
            @week_start.presence
  
      normalized = normalize_week_start(raw)
      [0, 1].include?(normalized) ? normalized : DEFAULT_WEEK_START
    end
    
    # Метод резолва с фильтрацией валидных типов и сохранением заданного пользователем порядка
    def resolved_enabled_rule_types(passed_types = nil)
      candidate = passed_types.presence || @enabled_rule_types.presence || ALL_RULE_TYPES
      candidate = Array(candidate).map(&:to_s)

      # Оставляем только допустимые значения, сохраняя порядок, заданный пользователем
      valid_types = candidate.select { |t| ALL_RULE_TYPES.include?(t) }
      valid_types.presence || ALL_RULE_TYPES
    end

    private
    def log_unsupported_locale_warning(locale)
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger && Rails.env.development?
        Rails.logger.warn("[RecurrenceUi] Locale '#{locale}' is not supported by the gem. Falling back to '#{DEFAULT_LOCALE}'. Supported locales: #{SUPPORTED_LOCALES.join(', ')}")
      end
    end
    def normalize_week_start(val)
      case val&.to_s&.downcase
      when '1', 'monday', 'mon' then 1
      when '0', 'sunday', 'sun' then 0
      else val.to_i
      end
    end
  end
end