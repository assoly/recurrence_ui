# lib/recurrence_ui/configuration.rb
module RecurrenceUi
  class Configuration
    
    SUPPORTED_LOCALES = %w[en ru ja uk be].freeze # Locales for which yml files are available in the gem
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

    attr_accessor :enabled_rule_types, :locale, :time_zone, :week_start, :supported_locales, :theme_mode
    def initialize
      @locale = nil
      @time_zone = nil
      @week_start = nil
      @theme_mode = :auto     # Example: :auto (default), :light (light only), :dark (dark only)
      @supported_locales = SUPPORTED_LOCALES
      @enabled_rule_types = ALL_RULE_TYPES.dup
    end

    def resolved_locale(requested = nil)
      # 1. Get the candidate locale
      # Priority: requested -> I18n.locale -> @locale
      candidate = requested&.to_s.presence ||
                  (defined?(I18n) && I18n.locale&.to_s.presence) ||
                  @locale&.to_s.presence

      # 2. Validate against supported locales
      if SUPPORTED_LOCALES.include?(candidate)
        candidate
      else
        # Log Unsupported Locale Warning: Log a warning in dev mode if an unsupported locale is received
        log_unsupported_locale_warning(candidate) if candidate.present?
        
        DEFAULT_LOCALE
      end
    end

    def resolved_time_zone(requested = nil)
      # Priority: requested -> Time.zone -> @time_zone
      candidate = requested.presence ||
                  (defined?(Time) && Time.respond_to?(:zone) && Time.zone&.name.presence) ||
                  @time_zone.presence
        # Check if the time zone exists in Rails
        if candidate.present? && defined?(ActiveSupport::TimeZone) && ActiveSupport::TimeZone[candidate].present?
            candidate
        else
            DEFAULT_TIME_ZONE
        end
    end

    def resolved_week_start(requested = nil)
      # Priority: requested -> Date.beginning_of_week -> @week_start
      rails_week_start = defined?(Date) && Date.respond_to?(:beginning_of_week) ? (Date.beginning_of_week == :monday ? 1 : 0) : nil

      raw = requested.presence ||
            rails_week_start ||
            @week_start.presence
  
      normalized = normalize_week_start(raw)
      [0, 1].include?(normalized) ? normalized : DEFAULT_WEEK_START
    end
    
    # Method for resolving enabled rule types with filtering and user-defined order preservation
    def resolved_enabled_rule_types(passed_types = nil)
      candidate = passed_types.presence || @enabled_rule_types.presence || ALL_RULE_TYPES
      candidate = Array(candidate).map(&:to_s)

      #Use only valid types, preserving the user-defined order
      valid_types = candidate.select { |t| ALL_RULE_TYPES.include?(t) }
      valid_types.presence || ALL_RULE_TYPES
    end

    private
    # Logs a warning in development mode if an unsupported locale is received
    def log_unsupported_locale_warning(locale)
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger && Rails.env.development?
        Rails.logger.warn("[RecurrenceUi] Locale '#{locale}' is not supported by the gem. Falling back to '#{DEFAULT_LOCALE}'. Supported locales: #{SUPPORTED_LOCALES.join(', ')}")
      end
    end
    # Normalizes the week_start value to either 0 (Sunday) or 1 (Monday)
    def normalize_week_start(val)
      case val&.to_s&.downcase
      when '1', 'monday', 'mon' then 1
      when '0', 'sunday', 'sun' then 0
      else val.to_i
      end
    end
  end
end