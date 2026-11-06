# lib/recurrence_ui/configuration.rb
module RecurrenceUi
  class Configuration
    
    SUPPORTED_LOCALES = %w[en ru ja uk be].freeze # Locales for which yml files are available in the gem
    DEFAULT_LOCALE = 'en'.freeze
    DEFAULT_TIME_ZONE = 'UTC'.freeze
    DEFAULT_START_TIME = '09:00'.freeze # Default start time if not specified
    DEFAULT_WEEK_START = 0
    DEFAULT_DURATION = 0 # Default duration in seconds if not specified
    DEFAULT_END_TIME = '17:00'.freeze # Default end time if not specified
    ALL_RULE_TYPES = %w[
          never
          daily
          weekly
          monthly_by_day_of_month
          monthly_by_weekday
          yearly_by_day_of_month
          yearly_by_weekday
        ].freeze

    attr_accessor :enabled_rule_types, #all rule  types that showing in select box in the UI, if not specified - all types will be shown
                  :locale, 
                  :time_zone, 
                  :week_start, # 0 for Sunday, 1 for Monday
                  :start_time,
                  :end_time,
                  :duration, # default duration in seconds if not specified
                  :supported_locales, 
                  :theme_mode, 
                  # default values for the fields in the UI and in DB
                  :default_recurring_rules_field,
                  # UI display options
                  :allow_multiple_rules, #show multiple rules in the UI if false - you can only have one rule at a time
                  :show_duration, # show duration field in the UI
                  :show_start_date_time, # show start time field in the UI
                  :show_end_date_time, # show end time (for  one occurrence) field in the UI
                  :show_exceptions, # show exception dates field in the UI
                  :show_rdates, # show additional date field in the UI
                  :show_termination, # show termination field in the UI (end date or count of occurrences)
                  :show_time_zone # show time zone field in the UI  

    
    def initialize
      @locale = nil
      @time_zone = nil
      @week_start = nil
      @duration = nil
      @start_time = nil
      @end_time = nil
      @theme_mode = :auto     # Example: :auto (default), :light (light only), :dark (dark only)
      @supported_locales = SUPPORTED_LOCALES
      @enabled_rule_types = ALL_RULE_TYPES.dup
      @default_recurring_rules_field = :recurring_rules
      


      # UI display options
      @allow_multiple_rules = true
      @show_duration = true
      @show_start_date_time = true
      @show_end_date_time = true
      @show_exceptions = true
      @show_rdates = true
      @show_termination = true
      @show_time_zone = true
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
    # Методы для резолва дефолтных значений длительности и времени старта
    def resolved_duration(passed = nil)
      passed.present? ? passed : (@duration.presence || DEFAULT_DURATION)
    end

    def resolved_start_time(passed = nil)
      # Если передано явно — используем его, иначе берем из конфига @start_time, либо захардкоженный дефолт
      passed.presence || @start_time.presence || DEFAULT_START_TIME
    end
    def resolved_end_time(passed = nil)
      passed.presence || @end_time.presence || DEFAULT_END_TIME
    end

    # Methods for resolving boolean display options with default values
    def resolved_allow_multiple_rules(passed = nil)
      passed.nil? ? @allow_multiple_rules : !!passed
    end
    def resolved_show_duration(passed = nil)
      passed.nil? ? @show_duration : !!passed
    end
    def resolved_show_start_date_time(passed = nil)
      passed.nil? ? @show_start_date_time : !!passed
    end

    def resolved_show_end_date_time(passed = nil)
      passed.nil? ? @show_end_date_time : !!passed
    end
     def resolved_show_exceptions(passed = nil)
      passed.nil? ? @show_exceptions : !!passed
    end
    def resolved_show_rdates(passed = nil)
      passed.nil? ? @show_rdates : !!passed
    end
    def resolved_show_termination(passed = nil)
      passed.nil? ? @show_termination : !!passed
    end
    def resolved_show_time_zone(passed = nil)
      passed.nil? ? @show_time_zone : !!passed
    end
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end
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