# app/services/recurrence_formatter_service.rb
module RecurrenceUi
  class RecurrenceFormatterService
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper

    DAY_SYMBOL_TO_INDEX = {
      sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
      sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6
    }.freeze

    attr_reader :event, :schedule, :locale, :time_zone, :week_start

    # Initializes the formatter service with either an event object or a schedule hash.
    #
    # @param target_or_hash [Object, Hash] Event record object (responding to #recurrence_raw_rules) 
    #   or a schedule raw hash.
    # @param options [Hash] Configuration options.
    # @option options [Symbol, String] :locale Custom locale for formatting (e.g., :en, :ru).
    # @option options [String, ActiveSupport::TimeZone] :time_zone Time zone override.
    # @option options [Integer, Symbol] :week_start Day index to start the week on.
    # @return [RecurrenceFormatterService]
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
      #@time_zone  = resolve_time_zone(options[:time_zone] || (@event.respond_to?(:event_time_zone) ? @event.event_time_zone : nil))
      #@week_start = resolve_week_start(options[:week_start])

      raw_rrules = @schedule[:rrules]
      @rrules = if raw_rrules.is_a?(Array)
                  raw_rrules
                elsif @schedule[:rule_type].present?
                  [@schedule]
                else
                  []
                end
    end

    # Generates a human-readable summary of the recurrence rules, exceptions, and additional dates.
    #
    # @return [ActiveSupport::SafeBuffer] HTML-safe string containing structured summary spans.
    def to_s
      main_text = if @rrules.present?
                    @rrules.map { |rule_hash| SingleRuleSummary.new(rule_hash, @locale).to_s }.join("; ")
                  else
                    I18n.t("recurrence_ui.one_time", locale: @locale, default: "Once")
                  end

      exceptions_text = format_date_list(:exdates, "recurrence_ui.labels.exceptions", "Except", "rui-meta-info--exceptions")
      rdates_text     = format_date_list(:rdates, "recurrence_ui.labels.rdates", "Also on", "rui-meta-info--rdates")

      main_html = tag.span(main_text, class: "rui-meta-info rui-meta-info--main")
      "#{main_html}#{exceptions_text}#{rdates_text}".strip.html_safe
    end

    # Formats the event's start time according to the given timezone and format.
    #
    # @param zone_type [Symbol, String] Target time zone scope (:application, :event, or custom zone string/object).
    # @param format [Symbol] Localization format key for I18n.l (e.g., :default, :short).
    # @param show_zone [Boolean] Whether to append the time zone abbreviation to the formatted output.
    # @return [String] Formatted start time string or "—" if event/time is absent.
    def start_time(zone_type = :application, format = :default, show_zone: false)
      format_event_time(:start_time_in_zone, zone_type, format, show_zone)
    end

    # Formats the event's end time according to the given timezone and format.
    #
    # @param zone_type [Symbol, String] Target time zone scope (:application, :event, or custom zone string/object).
    # @param format [Symbol] Localization format key for I18n.l (e.g., :default, :short).
    # @param show_zone [Boolean] Whether to append the time zone abbreviation to the formatted output.
    # @return [String] Formatted end time string or "—" if event/time is absent.
    def end_time(zone_type = :application, format = :default, show_zone: false)
      format_event_time(:end_time_in_zone, zone_type, format, show_zone)
    end

    # Форматирование времени начала (всегда выводит дату + время)
    def formatted_start_time(zone_type = :application, show_zone: false)
      return "—" unless @event

      target_zone = resolve_zone_type(zone_type)
      time = @event.start_time_in_zone(target_zone)
      return "—" unless time

      format_full_datetime(time, show_zone: show_zone)
    end

    # Форматирование времени окончания (с умной проверкой дат)
    def formatted_end_time(zone_type = :application, show_zone: false)
      return "—" unless @event

      target_zone = resolve_zone_type(zone_type)
      start_time = @event.start_time_in_zone(target_zone)
      end_time = @event.end_time_in_zone(target_zone)
      return "—" unless end_time

      # Если дата начала совпадает с датой окончания — выводим ТОЛЬКО время
      if start_time && start_time.to_date == end_time.to_date
        format_time_only(end_time, show_zone: show_zone)
      else
        # Если даты разные — выводим полную дату и время окончания
        format_full_datetime(end_time, show_zone: show_zone)
      end
    end



    # Formats the event's duration according to the given format.
    #
    # @param format [Symbol] Localization format key for I18n.l (e.g., :default, :short).
    # @return [String] Formatted duration string or "—" if event/time is absent.

    def formatted_duration
      dur = @event.current_duration_seconds
      return "—" if dur <= 0

      total_minutes = (dur / 60).to_i
      return "—" if total_minutes <= 0

      days = total_minutes / 1440
      hours = (total_minutes % 1440) / 60
      minutes = total_minutes % 60

      parts = []
      parts << I18n.t('recurrence_ui.duration.days', count: days) if days > 0
      parts << I18n.t('recurrence_ui.duration.hours', count: hours) if hours > 0
      parts << I18n.t('recurrence_ui.duration.minutes', count: minutes) if minutes > 0

      parts.any? ? parts.join(' ') : I18n.t('recurrence_ui.duration.minutes', count: 0)
    end
# Форматированные ближайшие повторения с умной проверкой окончания
    def formatted_upcoming_occurrences(limit = 5, zone_type = :event, show_end_time: false, show_zone: false)
      return [] unless @event

      target_zone = resolve_zone_type(zone_type)
      occurrences = @event.upcoming_occurrences_in_zone(limit, Time.current, zone_type)

      occurrences.map do |occ|
        start_str = format_full_datetime(occ.start_time, show_zone: show_zone)

        if show_end_time && occ.end_time.present?
          end_str = if occ.start_time.to_date == occ.end_time.to_date
                      format_time_only(occ.end_time, show_zone: show_zone)
                    else
                      format_full_datetime(occ.end_time, show_zone: show_zone)
                    end
          
          # Разделитель между началом и окончанием (можно настроить в YAML или оставить дефис)
          separator = " – " 
          "#{start_str}#{separator}#{end_str}"
        else
          start_str
        end
      end
    end

    # Calculates and formats upcoming occurrences of the event.
    #
    # @param limit [Integer] Maximum number of occurrences to retrieve.
    # @param zone_type [Symbol, String] Target time zone scope (:event, :application, or custom zone).
    # @param format [Symbol] Localization format key for I18n.l.
    # @param show_zone [Boolean] Whether to append the time zone abbreviation to each formatted time.
    # @return [Array<Hash{Symbol => String, nil}>] Array of hashes containing formatted :start_time and :end_time strings.
    def upcoming_occurrences(limit = 5, zone_type = :event, format = :default, show_zone: false)
      return [] unless @event

      occurrences = @event.upcoming_occurrences_in_zone(limit, Time.current, zone_type)

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

    # Formats a date or date-string into a localized string with optional time zone offset.
    #
    # @param date_or_string [Date, Time, String] Date representation to be formatted.
    # @param locale [Symbol, String] Target locale for translation.
    # @param show_time_zone [Boolean] Whether to append time zone offset information.
    # @param time_zone [ActiveSupport::TimeZone, String, nil] Time zone object or string name.
    # @return [String] Formatted date string, or an empty string if input is blank.
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

    # Вспомогательный метод для вывода полной даты  + времени
    def format_full_datetime(time, show_zone: false)
      # 1. Берем дату через ваш кастомный метод (с правильными падежами месяцев)
      date_str = self.class.format_date(time, @locale)
      
      # 2. Берем единый формат времени из локали
      time_format = I18n.t("recurrence_ui.time.formats.time_only", locale: @locale, default: "%H:%M")
      time_str = time.strftime(time_format)
      
      # 3. Соединяем через разделитель из локали
      separator = I18n.t("recurrence_ui.time.formats.separator", locale: @locale, default: ", ")
      
      result = "#{date_str}#{separator}#{time_str}"
      show_zone ? "#{result} (#{time.strftime('%Z')})" : result
    end

    # Вспомогательный метод для вывода только времени (если дата та же)
    def format_time_only(time, show_zone: false)
      time_format = I18n.t("recurrence_ui.time.formats.time_only", locale: @locale, default: "%H:%M")
      result = time.strftime(time_format)
      
      show_zone ? "#{result} (#{time.strftime('%Z')})" : result
    end


    # Formats a specific event time (start or end) based on the provided method name, time zone, and format.
    #
    # @param method_name [Symbol] Method to call on the event object (:start_time_in_zone or :end_time_in_zone).
    # @param zone_type [Symbol, String] Time zone scope (:event, :application, or custom zone).
    # @param format [Symbol] Localization format key for I18n.l.
    # @param show_zone [Boolean] Whether to append the time zone abbreviation to the formatted output.
    # @return [String] Formatted time string or "—" if event/time is absent.  
    def format_event_time(method_name, zone_type, format, show_zone)
      return "—" unless @event

      target_zone = resolve_zone_type(zone_type)
      time = @event.public_send(method_name, target_zone)
      return "—" unless time

      formatted = I18n.l(time, format: format, locale: @locale)
      show_zone ? "#{formatted} (#{time.strftime('%Z')})" : formatted
    end

    # Formats a list of dates from the schedule for a given key, returning an HTML span with the label and formatted dates.
    #
    # @param schedule_key [Symbol] Key in the schedule hash (e.g., :exdates, :rdates).
    # @param i18n_key [String] I18n translation key for the label.
    # @param default_label [String] Default label to use if translation is missing.
    # @param css_class [String] Additional CSS class to apply to the span.
    # @return [ActiveSupport::SafeBuffer, String] HTML span tag with formatted dates, or an empty string if no dates are present. 
    def format_date_list(schedule_key, i18n_key, default_label, css_class)
      dates = @schedule[schedule_key]
      return "" if dates.blank?

      label = I18n.t(i18n_key, locale: @locale, default: default_label)
      formatted_dates = dates.map { |d| self.class.format_date(d, @locale) }

      tag.span("#{label}: #{formatted_dates.join(', ')}", class: "rui-meta-info #{css_class}")
    end

    # Resolves and normalizes the target time zone based on the provided scope or type.
    #
    # @param zone_type [Symbol, String, nil] Time zone selector (:event, :application, :app, or a specific zone name/object).
    # @return [ActiveSupport::TimeZone] Resolved ActiveSupport time zone object.
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

    # Resolves the locale to be used, falling back to the gem configuration default.
    #
    # @param passed_locale [Symbol, String, nil] Explicitly requested locale.
    # @return [Symbol, String] Resolved locale code.
    def resolve_locale(passed_locale)
      passed_locale || RecurrenceUi.config.resolved_locale
    end

    # Resolves the time zone to be used, falling back to the gem configuration default.
    #
    # @param passed_tz [String, ActiveSupport::TimeZone, nil] Explicitly requested time zone.
    # @return [ActiveSupport::TimeZone, String] Resolved time zone.
    def resolve_time_zone(passed_tz)
      passed_tz || RecurrenceUi.config.resolved_time_zone
    end

    # Resolves the starting day of the week, falling back to the gem configuration default.
    #
    # @param passed_ws [Integer, String, nil] Explicitly requested week start index (0-6).
    # @return [Integer] Resolved week start day index.
    def resolve_week_start(passed_ws)
      return passed_ws.to_i if passed_ws.present?
      RecurrenceUi.config.resolved_week_start
    end

    # Inner class for formatting an individual rule (equivalent to _buildRuleSummaryText in JS)
    class SingleRuleSummary
      include ActionView::Helpers::TextHelper

      # Initializes the single rule summary formatter with a rule hash and locale.
      #
      # @param rule_hash [Hash] Raw hash containing rule definitions and validations.
      # @param locale [Symbol, String] Target locale for translation.
      # @return [SingleRuleSummary]
      def initialize(rule_hash, locale)
        @hash = rule_hash.with_indifferent_access
        @locale = locale
        @validations = @hash[:validations] || {}
        @type = determine_rule_type
        @interval = (@hash[:interval] || 1).to_i
      end

      # Generates a localized human-readable summary string for the individual recurrence rule.
      #
      # @return [String] Formatted and squished rule summary string.
      def to_s
        return I18n.t("recurrence_ui.one_time", locale: @locale) if @type == :never

        # 1. Interval number is formatted purely via I18n (no hardcoded languages in code!)
        count_f = format_interval_number(@interval, interval_gender)

        # 2. Termination (until date or count)
        # Use format_date for :until
        termination = if @hash[:until]
                        date_str = RecurrenceFormatterService.format_date(@hash[:until], @locale)
                        I18n.t("recurrence_ui.until_label", date: date_str, locale: @locale)
                      elsif @hash[:count]
                        I18n.t("recurrence_ui.count_label", count: @hash[:count], locale: @locale)
                      else
                        ""
                      end

        # 3. Days of week / Days of month
        weekdays_str = format_weekdays
        month_str = format_month
        days_of_month_str = format_days_of_month

        # 4. Main template assembly (pass count: @interval for pluralization)
        # Determine key suffix (.one or .other)
        plural_suffix = @interval == 1 ? "one" : "other"
        base_key = "recurrence_ui.summary.#{@type}"

        I18n.t(
          "#{base_key}.#{plural_suffix}",
          count: @interval,
          count_f: count_f,
          until: termination,
          weekdays: weekdays_str,
          month: month_str,
          days_of_month: days_of_month_str,
          locale: @locale,
          default: [base_key.to_sym] # Fallback to base key if .one/.other keys do not exist
        ).to_s.squish
      end

      private
      # Determines the specific type of rule based on rule configurations and validations.
      #
      # @return [Symbol] Rule type identifier (e.g., :never, :daily, :monthly_by_weekday, etc.).
      def determine_rule_type
        return :never if @hash[:rule_type].blank?
        base = @hash[:rule_type].gsub(/IceCube::|Rule/, "").downcase
        if base == "monthly"
          @validations[:day_of_week] ? :monthly_by_weekday : :monthly_by_day_of_month
        elsif base == "yearly"
          @validations[:day_of_week] ? :yearly_by_weekday : :yearly_by_day_of_month
        else
          base.to_sym
        end
      end

      # Formats the interval number using localized ordinal templates.
      #
      # @param number [Integer] The interval step value.
      # @param gender [Symbol] Gender/context classification key for localization.
      # @return [String] Formatted interval number string.
      def format_interval_number(number, gender)
        I18n.t("recurrence_ui.ordinals.#{gender}.other", count: number, locale: @locale, default: number.to_s)
      end

      # Formats an ordinal number (e.g., 1st, 2nd) considering language rules and target contexts.
      #
      # @param number [Integer] The day or position number.
      # @param gender [Symbol] Context or gender key for translation lookups.
      # @return [String] Formatted ordinal string.
      def format_ordinal(number, gender = :male)
        key = number.to_s

        # 1. Search for exact match considering context/gender (e.g., :day_of_month, :female, etc.)
        if gender.present?
          specific_gender = I18n.t("recurrence_ui.nth_names.#{gender}.#{key}", locale: @locale, default: nil)
          return specific_gender if specific_gender.present?
        end

        # 2. Search in general nth_names ONLY for weekdays (when gender is NOT :day_of_month)
        if gender != :day_of_month
          specific_general = I18n.t("recurrence_ui.nth_names.#{key}", locale: @locale, default: nil)
          return specific_general if specific_general.present?
        end

        # 3. Format via ordinals (for days of month and regular intervals)
        # Get the pluralization rule for the number (for English 2 -> :two, 3 -> :few, 21 -> :one etc.)
        rule = ordinal_rule_for(number)

        ordinal = if gender.present?
                    I18n.t("recurrence_ui.ordinals.#{gender}.#{rule}", locale: @locale, default: nil) ||
                    I18n.t("recurrence_ui.ordinals.#{gender}.other", locale: @locale, default: nil)
                  end

        ordinal ||= I18n.t("recurrence_ui.ordinals.#{rule}", locale: @locale, default: nil) ||
                    I18n.t("recurrence_ui.ordinals.other", locale: @locale, default: nil)

        if ordinal.is_a?(String) && ordinal.include?("%{count}")
          return ordinal.gsub("%{count}", number.to_s)
        elsif ordinal.is_a?(String)
          return ordinal
        end

        number.to_s
      end

      # Provides localized connector options for sentence assembly (joins arrays of strings).
      #
      # @return [Hash{Symbol => String}] Options hash containing connectors (`words_connector`, etc.).
      def sentence_options
        {
          words_connector: I18n.t("recurrence_ui.list.words_connector", locale: @locale, default: ", "),
          two_words_connector: I18n.t("recurrence_ui.list.two_words_connector", locale: @locale, default: " and "),
          last_word_connector: I18n.t("recurrence_ui.list.last_word_connector", locale: @locale, default: " and ")
        }
      end

      # Determines the grammatical gender/context key for interval pluralization rules.
      #
      # @return [Symbol] Gender key (`:weekly_interval` or `:male`).
      def interval_gender
        @type == :weekly ? :weekly_interval : :male
      end

      # Determines the language-independent pluralization rule category for a given number.
      #
      # @param number [Integer] The numeric value to evaluate.
      # @return [Symbol] The pluralization category rule (`:one`, `:two`, `:few`, or `:other`).
      def ordinal_rule_for(number)
        n = number.abs
        
        #  Handling exceptions for 11, 12, 13 (for EN and other languages)
        return :other if (11..13).cover?(n % 100)

        case n % 10
        when 1 then :one
        when 2 then :two
        when 3 then :few
        else :other
        end
      end

      # Formats days of the week or weekday validation rules into a human-readable sentence.
      #
      # @return [String, nil] Formatted weekdays description string.
      def format_weekdays
        if @type == :weekly && @validations[:day]
          day_names = I18n.t("recurrence_ui.weekdays.day_names_plural", locale: @locale)
          names = @validations[:day].map do |d|
            idx = d.is_a?(Symbol) ? DAY_SYMBOL_TO_INDEX[d] : d.to_i
            day_names[idx] if idx
          end.compact
          names.to_sentence(sentence_options)
        elsif @validations[:day_of_week]
          parts = @validations[:day_of_week].map do |day_idx, nths|
            day_idx = day_idx.is_a?(Symbol) ? DAY_SYMBOL_TO_INDEX[day_idx] : day_idx.to_i
            gender = I18n.t("recurrence_ui.weekdays.weekday_genders", locale: @locale)[day_idx]
            formatted_nths = nths.map { |n| format_ordinal(n, gender) }
            day_name = I18n.t("recurrence_ui.weekdays.day_names", locale: @locale)[day_idx]
            "#{formatted_nths.to_sentence(sentence_options)} #{day_name}"
          end
          parts.join("; ")
        end
      end

      # Formats the target month name for yearly rules.
      #
      # @return [String, nil] Localized month name.
      def format_month
        return unless @validations[:month_of_year]
        idx = @validations[:month_of_year].first
        return unless idx

        I18n.t("recurrence_ui.in_month_names_yearly", locale: @locale)[idx]
      end

      # Formats days of the month validation rules.
      #
      # @return [String, nil] Formatted days of the month string.
      def format_days_of_month
        return nil unless @validations[:day_of_month]

        formatted_dates = @validations[:day_of_month].map do |d|
          format_ordinal(d, :day_of_month)
        end

        list_str = formatted_dates.to_sentence(sentence_options)
        I18n.t("recurrence_ui.days_of_month_fmt", list: list_str, locale: @locale)
      end
    end
  end

end