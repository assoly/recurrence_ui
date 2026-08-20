# lib/recurrence_ui/configuration.rb
module RecurrenceUi
  class Configuration
    SUPPORTED_LOCALES = %w[en ru ja].freeze # Локали, для которых есть yml-файлы в геме
    DEFAULT_LOCALE = 'en'.freeze
    DEFAULT_TIME_ZONE = 'UTC'.freeze
    DEFAULT_WEEK_START = 0

    attr_accessor :locale, :time_zone, :week_start

    def initialize
      @locale = nil
      @time_zone = nil
      @week_start = nil
    end

    # 1. Сначала проверяем явный конфиг гема (если разработчик переопределил)
    # 2. Если nil -> берём из I18n приложения
    # 3. Если и там nil -> берем дефолт гема ('en')
    def resolved_locale(requested = nil)
      # 1. Собираем кандидатную локаль
      candidate = requested&.to_s.presence ||
                  @locale&.to_s.presence ||
                  (defined?(I18n) && I18n.locale&.to_s.presence)

      # 2. Валидируем против поддерживаемых гемом
      if SUPPORTED_LOCALES.include?(candidate)
        candidate
      else
        # Необязательно: Логируем предупреждение в dev-режиме, если пришел :fr
        log_unsupported_locale_warning(candidate) if candidate.present?
        
        DEFAULT_LOCALE
      end
    end

    # 1. Сначала конфиг гема
    # 2. Если nil -> берем текущую Time.zone из Rails
    # 3. Если nil -> берем дефолт ('UTC')
    def resolved_time_zone(requested = nil)
        candidate = requested.presence || @time_zone.presence || (defined?(Time) && Time.respond_to?(:zone) && Time.zone&.name.presence)
        
        # Проверяем, существует ли такой часовой пояс в Rails
        if candidate.present? && defined?(ActiveSupport::TimeZone) && ActiveSupport::TimeZone[candidate].present?
            candidate
        else
            DEFAULT_TIME_ZONE
        end
    end



    # 1. Сначала конфиг гема
    # 2. Если nil -> определяем из Rails (Date.beginning_of_week)
    # 3. Если nil -> берем дефолт (0 - Sunday)
    def resolved_week_start(requested = nil)
  raw = requested.presence || @week_start.presence || (defined?(Date) && Date.respond_to?(:beginning_of_week) && (Date.beginning_of_week == :monday ? 1 : 0))
  
  normalized = normalize_week_start(raw)
  [0, 1].include?(normalized) ? normalized : DEFAULT_WEEK_START
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