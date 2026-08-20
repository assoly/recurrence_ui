# lib/recurrence_ui/configuration.rb
module RecurrenceUi
  class Configuration
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
    def resolved_locale
      @locale&.to_s.presence || 
        (defined?(I18n) && I18n.locale&.to_s.presence) || 
        DEFAULT_LOCALE
    end

    # 1. Сначала конфиг гема
    # 2. Если nil -> берем текущую Time.zone из Rails
    # 3. Если nil -> берем дефолт ('UTC')
    def resolved_time_zone
      @time_zone.presence || 
        (defined?(Time) && Time.respond_to?(:zone) && Time.zone&.name.presence) || 
        DEFAULT_TIME_ZONE
    end

    # 1. Сначала конфиг гема
    # 2. Если nil -> определяем из Rails (Date.beginning_of_week)
    # 3. Если nil -> берем дефолт (0 - Sunday)
    def resolved_week_start
      return normalize_week_start(@week_start) if @week_start.present?

      if defined?(Date) && Date.respond_to?(:beginning_of_week)
        Date.beginning_of_week == :monday ? 1 : 0
      else
        DEFAULT_WEEK_START
      end
    end

    private

    def normalize_week_start(val)
      case val&.to_s&.downcase
      when '1', 'monday', 'mon' then 1
      when '0', 'sunday', 'sun' then 0
      else val.to_i
      end
    end
  end
end