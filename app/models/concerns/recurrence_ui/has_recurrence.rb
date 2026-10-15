# recurrence_ui/app/models/concerns/recurrence_ui/has_recurrence.rb
module RecurrenceUi
  module HasRecurrence
    extend ActiveSupport::Concern

    included do
      #There are class variables for storing field names for a specific model
      class_attribute :recurrence_rules_field, default: RecurrenceUi.config.default_recurring_rules_field
      class_attribute :recurrence_start_time_field, default: RecurrenceUi.config.default_start_time_field
      class_attribute :recurrence_end_time_field, default: RecurrenceUi.config.default_end_time_field
      class_attribute :recurrence_time_zone_field, default: RecurrenceUi.config.default_time_zone_field
      class_attribute :recurrence_duration_field, default: RecurrenceUi.config.default_duration_field

      before_save     :calculate_missing_time_attributes
    end

    class_methods do
      # DSL-method for configuring fields in the model
      def has_recurrence(rules: nil, start_time: nil, end_time: nil, time_zone: nil, duration: nil)
        self.recurrence_rules_field      = rules      if rules.present?
        self.recurrence_start_time_field = start_time if start_time.present?
        self.recurrence_end_time_field   = end_time   if end_time.present?
        self.recurrence_time_zone_field  = time_zone  if time_zone.present?
        self.recurrence_duration_field   = duration   if duration.present?

        field_name = recurrence_rules_field.to_s

        # 1. READING: Always return a Hash (regardless of what's in the DB)
        define_method(field_name) do
          raw_val = read_attribute(field_name)
          return {} if raw_val.blank?

          if raw_val.is_a?(Hash)
            raw_val.with_indifferent_access
          elsif raw_val.is_a?(String)
            begin
              # Пробуем распарсить как JSON
              JSON.parse(raw_val).with_indifferent_access
            rescue JSON::ParserError
              begin
                # Для старых текстовых колонок (как recurring_rules в Event)
                YAML.safe_load(raw_val, permitted_classes: [Symbol, Time, Date, ActiveSupport::TimeWithZone]).with_indifferent_access
              rescue StandardError
                {}
              end
            end
          else
            {}
          end
        end

        # 2. SAVING: Safely accept Hash, JSON string or nil
        define_method("#{field_name}=") do |value|
          parsed_value = case value
                         when String
                           begin
                             JSON.parse(value)
                           rescue JSON::ParserError
                             nil
                           end
                         when Hash, ActionController::Parameters
                           value.to_h
                         else
                           nil
                         end

          if parsed_value.present?
            write_attribute(field_name, parsed_value.deep_stringify_keys)
          else
            write_attribute(field_name, nil)
          end
        end
      end
    end

    # --- Instance Methods ---
    def recurrence_raw_rules
      public_send(self.class.recurrence_rules_field)
    end

    def event_time_zone
      if self.class.recurrence_time_zone_field && respond_to?(self.class.recurrence_time_zone_field)
        tz_name = public_send(self.class.recurrence_time_zone_field)
      end
      zone_name = tz_name.presence || Time.zone&.name
      ActiveSupport::TimeZone[zone_name] || Time.zone
    end

    def recurrence_start_time
      if self.class.recurrence_start_time_field && respond_to?(self.class.recurrence_start_time_field)
        raw_start = public_send(self.class.recurrence_start_time_field)
      end
      (raw_start || Time.current).in_time_zone(event_time_zone)
    end

    # Получение значения длительности из соответствующего поля модели (в секундах)
    def current_duration_seconds
      dur_field = self.class.recurrence_duration_field
      if dur_field && respond_to?(dur_field)
        val = public_send(dur_field)
        return val.to_i if val.present? && val.to_i > 0
      end
      0
    end

    # Красиво отформатированная длительность для вывода во вьюхе
    def formatted_duration
      dur = current_duration_seconds
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

    # --- Building IceCube::Schedule ---

    def schedule(start_time_override = nil)
      base_time = start_time_override || recurrence_start_time
      s = IceCube::Schedule.new(base_time)

      dur = current_duration_seconds
      s.duration = dur if dur > 0

      raw_rules = recurrence_raw_rules
      return s if raw_rules.blank?

      data = raw_rules.is_a?(String) ? (JSON.parse(raw_rules) rescue {}) : raw_rules
      data = data.deep_stringify_keys if data.is_a?(Hash)

      rules_array = data['rrules'] || [data]

      rules_array.each do |rule_hash|
        next if rule_hash.blank? || !rule_hash.is_a?(Hash)

        # Correct 0 -> 7 for IceCube::MonthlyRule (day_of_week)
        if rule_hash['rule_type'] == 'IceCube::MonthlyRule' &&
           rule_hash.dig('validations', 'day_of_week').is_a?(Hash)
          
          rule_hash['validations']['day_of_week'].transform_values! do |days|
            Array(days).map { |day| day.to_i == 0 ? 7 : day.to_i }
          end
        end

        begin
          r = IceCube::Rule.from_hash(rule_hash)
          if respond_to?(:repeat_until) && repeat_until.present? && !rule_hash['until']
            r = r.until(repeat_until.in_time_zone(event_time_zone).end_of_day)
          end
          s.add_recurrence_rule(r)
        rescue StandardError => e
          Rails.logger.error "[RecurrenceUi] Error building IceCube::Rule: #{e.message}"
        end
      end

      Array(data['exdates']).each do |exdate|
        next if exdate.blank?
        parsed_date = Date.parse(exdate.to_s) rescue nil
        next unless parsed_date

        exact_datetime = base_time.change(
          year:  parsed_date.year,
          month: parsed_date.month,
          day:   parsed_date.day
        )
        s.add_exception_time(exact_datetime)
      end

      Array(data['rdates']).each do |rdate|
        next if rdate.blank?
        parsed_date = Date.parse(rdate.to_s) rescue nil
        next unless parsed_date

        exact_datetime = base_time.change(
          year:  parsed_date.year,
          month: parsed_date.month,
          day:   parsed_date.day
        )
        s.add_recurrence_time(exact_datetime)
      end

      s
    end

    # Next occurrence dates considering the time zone
    def upcoming_occurrences(limit = 5, from_time = Time.current)
      schedule.next_occurrences(limit, from_time.in_time_zone(event_time_zone))
    end

    # First rule (for backward compatibility)
    def rule
      schedule.recurrence_rules.first
    end

    # Textual description of the rule / schedule
    def recurring_text
      return I18n.t("recurrence_ui.once", default: "Once") if recurrence_raw_rules.blank?

      schedule.to_s
    end
    private 
    
    def calculate_missing_time_attributes
      dur_field = self.class.recurrence_duration_field
      end_field = self.class.recurrence_end_time_field
      start_field = self.class.recurrence_start_time_field

      return unless dur_field && end_field && start_field
      return unless respond_to?(start_field) && respond_to?(end_field) && respond_to?("#{dur_field}=")

      start_val = public_send(start_field)
      end_val = public_send(end_field)
      current_dur = respond_to?(dur_field) ? public_send(dur_field) : nil

      # Если есть старт и окончание, но нет длительности — считаем длительность
      if start_val.present? && end_val.present? && current_dur.blank?
        calculated_dur = (end_val - start_val).to_i
        public_send("#{dur_field}=", calculated_dur) if calculated_dur > 0
      # Если есть старт и длительность, но нет окончания — вычисляем окончание
      elsif start_val.present? && current_dur.present? && end_val.blank? && respond_to?("#{end_field}=")
        calculated_end = start_val + current_dur.seconds
        public_send("#{end_field}=", calculated_end)
      end
    end
  end
end