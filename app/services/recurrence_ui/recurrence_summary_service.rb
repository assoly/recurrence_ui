# app/services/recurrence_summary_service.rb
module RecurrenceUi
  class RecurrenceSummaryService
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper

    DAY_SYMBOL_TO_INDEX = {
      sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6,
      sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6
    }.freeze

    def initialize(rule_hash, locale = I18n.locale)
      @hash = rule_hash.with_indifferent_access
      @locale = locale.to_sym
      @validations = @hash[:validations] || {}
      @type = determine_rule_type
      @interval = (@hash[:interval] || 1).to_i
    end

    def to_s
      return I18n.t("recurrence_ui.one_time", locale: @locale) if @type == :never

      # 1. Число интервала форматируется чисто через I18n (без хардкода языков в коде!)
      count_f = format_interval_number(@interval, interval_gender)
      
      # 2. Окончание (до даты или кол-во раз)
      termination = if @hash[:until]
                      date = I18n.l(Date.parse(@hash[:until].to_s), format: :long, locale: @locale)
                      I18n.t("recurrence_ui.until_label", date: date, locale: @locale)
                    elsif @hash[:count]
                      I18n.t("recurrence_ui.count_label", count: @hash[:count], locale: @locale)
                    else
                      ""
                    end

      # 3. Дни недели / Числа месяца
      weekdays_str = format_weekdays
      month_str = format_month
      days_of_month_str = format_days_of_month

      # 4. Сборка основного шаблона (передаем count: @interval для плюрализации)
      main_text = I18n.t("recurrence_ui.summary.#{@type}", 
        count: @interval,
        count_f: count_f,
        until: termination,
        weekdays: weekdays_str,
        month: month_str,
        days_of_month: days_of_month_str,
        locale: @locale
      ).to_s.squish

      # 5. Исключения
      exceptions_text = format_exceptions

      "#{main_text}#{exceptions_text}".strip.html_safe
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

    # Универсальный метод форматирования интервала: берет шаблон из YAML текущей локали
    def format_interval_number(number, gender)
      I18n.t("recurrence_ui.ordinals.#{gender}.other", count: number, locale: @locale, default: number.to_s)
    end

    # Порядковое числительное для N-го дня (например, 1-й вторник, 第1火曜日, 1st Tuesday)
    def format_ordinal(number, gender)
      # 1. Точечный перехват (например, nth_names.female.1 -> "1-я" или nth_names.male.-1 -> "посл.")
      specific = I18n.t("recurrence_ui.nth_names.#{gender}.#{number}", locale: @locale, default: nil)
      return specific if specific

      # 2. Общий фолбек на ordinals
      ordinal = I18n.t("recurrence_ui.ordinals.#{gender}", count: number, locale: @locale, default: nil)
      return ordinal if ordinal.is_a?(String)

      number.to_s
    end

    def interval_gender
      @type == :weekly ? :weekly_interval : :male
    end

    def format_weekdays
      if @type == :weekly && @validations[:day]
        day_names = I18n.t("recurrence_ui.weekdays.day_names_plural", locale: @locale)
        names = @validations[:day].map do |d|
          idx = d.is_a?(Symbol) ? DAY_SYMBOL_TO_INDEX[d] : d.to_i
          day_names[idx] if idx
        end.compact
        names.to_sentence(locale: @locale)
      elsif @validations[:day_of_week]
        parts = @validations[:day_of_week].map do |day_idx, nths|
          day_idx = day_idx.is_a?(Symbol) ? DAY_SYMBOL_TO_INDEX[day_idx] : day_idx.to_i
          gender = I18n.t("recurrence_ui.weekdays.weekday_genders", locale: @locale)[day_idx]
          formatted_nths = nths.map { |n| format_ordinal(n, gender) }
          day_name = I18n.t("recurrence_ui.weekdays.day_names", locale: @locale)[day_idx]
          "#{formatted_nths.to_sentence(locale: @locale)} #{day_name}"
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

      list_str = formatted_dates.to_sentence(locale: @locale)

      I18n.t("recurrence_ui.days_of_month_fmt", list: list_str, locale: @locale)
    end

    def format_exceptions
      return "" if @hash[:exdates].blank?
      
      except_label = I18n.t("recurrence_ui.labels.exceptions", locale: @locale)
      formatted_dates = @hash[:exdates].map { |d| Date.parse(d.to_s) }.sort
      dates_str = formatted_dates.map { |d| I18n.l(d, format: :long, locale: @locale) }.join(", ")
      
      "<br><span class='text-muted text-sm italic'>#{except_label}: #{dates_str}</span>"
    end
  end
end