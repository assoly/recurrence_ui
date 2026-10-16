# app/services/recurrence_summary_service.rb
module RecurrenceUi
  class RecurrenceSummaryService
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper

    DAY_SYMBOL_TO_INDEX = {
      sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
      sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6
    }.freeze

    def initialize(schedule_hash, options = {})
      @schedule = schedule_hash.with_indifferent_access.except(:duration_mode, 'duration_mode')
      
      # 1. Configuration resolution priority (Method options -> Initializer -> Gem/Rails defaults)
      @locale     = resolve_locale(options[:locale])
      @time_zone  = resolve_time_zone(options[:time_zone])
      @week_start = resolve_week_start(options[:week_start])

      # Extract rrules (maintaining backward compatibility with single rule hashes)
      raw_rrules = @schedule[:rrules]
      @rrules = if raw_rrules.is_a?(Array)
                  raw_rrules
                elsif @schedule[:rule_type].present?
                  [@schedule]
                else
                  []
                end
    end

    def to_s
      main_text = if @rrules.present?
                    @rrules.map { |rule_hash| SingleRuleSummary.new(rule_hash, @locale).to_s }.join("; ")
                  else
                    I18n.t("recurrence_ui.one_time", locale: @locale)
                  end

      exceptions_text = format_exceptions
      rdates_text = format_rdates
      main_html = tag.span(main_text, class: "rui-meta-info rui-meta-info--main")           
      "#{main_html}#{exceptions_text}#{rdates_text}".strip.html_safe    
    end

    def self.format_date(date_or_string, locale)
      return '' if date_or_string.blank?

      date = date_or_string.is_a?(String) ? Date.parse(date_or_string) : date_or_string.to_date

      format_pattern = I18n.t("recurrence_ui.date.formats.recurrence_date", locale: locale, default: "%-d %B %Y")
      month_names = I18n.t("recurrence_ui.date.month_names", locale: locale)
      month_name = month_names[date.month] || ""

      format_pattern
        .gsub("%Y", date.year.to_s)
        .gsub("%-m", date.month.to_s)
        .gsub("%m", date.month.to_s.rjust(2, '0'))
        .gsub("%-d", date.day.to_s)
        .gsub("%d", date.day.to_s.rjust(2, '0'))
        .gsub("%B", month_name)
    end

    private

    # Process configuration parameters: locale, time_zone, week_start
    # Use priority: passed parameter -> RecurrenceUi config -> Rails/I18n default
    # Priority: passed locale -> config.locale -> I18n.locale -> :en
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

  
    # Exception formatting method
    def format_exceptions
      return "" if @schedule[:exdates].blank?

      except_label = I18n.t("recurrence_ui.labels.exceptions", locale: @locale)
      formatted_dates = @schedule[:exdates].map { |d| self.class.format_date(d, @locale) }
      dates_str = formatted_dates.join(", ")

      tag.span("#{except_label}: #{dates_str}", class: "rui-meta-info rui-meta-info--exceptions")
    end

    # Additions (rdates) formatting method
    def format_rdates
      return "" if @schedule[:rdates].blank?

      rdate_label = I18n.t("recurrence_ui.labels.rdates", locale: @locale)
      formatted_dates = @schedule[:rdates].map { |d| self.class.format_date(d, @locale) }
      dates_str = formatted_dates.join(", ")

      tag.span("#{rdate_label}: #{dates_str}", class: "rui-meta-info rui-meta-info--rdates")
    end

    # Inner class for formatting an individual rule (equivalent to _buildRuleSummaryText in JS)
    class SingleRuleSummary
      include ActionView::Helpers::TextHelper

      def initialize(rule_hash, locale)
        @hash = rule_hash.with_indifferent_access
        @locale = locale
        @validations = @hash[:validations] || {}
        @type = determine_rule_type
        @interval = (@hash[:interval] || 1).to_i
      end

      def to_s
        return I18n.t("recurrence_ui.one_time", locale: @locale) if @type == :never

        # 1. Interval number is formatted purely via I18n (no hardcoded languages in code!)
        count_f = format_interval_number(@interval, interval_gender)

        # 2. Termination (until date or count)
        # Use format_date for :until
        termination = if @hash[:until]
                        date_str = RecurrenceSummaryService.format_date(@hash[:until], @locale)
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

      # Universal interval formatting method: retrieves template from current locale's YAML
      def format_interval_number(number, gender)
        I18n.t("recurrence_ui.ordinals.#{gender}.other", count: number, locale: @locale, default: number.to_s)
      end

      # Ordinal number for N-th day (e.g., 1st Tuesday, 第1火曜日, 1-й вторник)
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

      def sentence_options
        {
          words_connector: I18n.t("recurrence_ui.list.words_connector", locale: @locale, default: ", "),
          two_words_connector: I18n.t("recurrence_ui.list.two_words_connector", locale: @locale, default: " and "),
          last_word_connector: I18n.t("recurrence_ui.list.last_word_connector", locale: @locale, default: " and ")
        }
      end

      def interval_gender
        @type == :weekly ? :weekly_interval : :male
      end

      # Helper method for determining the ordinal category (language-independent)
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

      def format_month
        return unless @validations[:month_of_year]
        idx = @validations[:month_of_year].first
        return unless idx

        I18n.t("recurrence_ui.in_month_names_yearly", locale: @locale)[idx]
      end

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