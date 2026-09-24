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
    end

    class_methods do
      # DSL-method for configuring fields in the model
      def has_recurrence(rules: nil, start_time: nil, end_time: nil, time_zone: nil)
        self.recurrence_rules_field      = rules      if rules.present?
        self.recurrence_start_time_field = start_time if start_time.present?
        self.recurrence_end_time_field   = end_time   if end_time.present?
        self.recurrence_time_zone_field  = time_zone  if time_zone.present?

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

    def event_duration
      return 0 unless self.class.recurrence_end_time_field && respond_to?(self.class.recurrence_end_time_field)

      raw_end = public_send(self.class.recurrence_end_time_field)
      return 0 if raw_end.blank?

      (raw_end - recurrence_start_time).to_i
    end

    # --- Building IceCube::Schedule ---

    def schedule(start_time_override = nil)
      base_time = start_time_override || recurrence_start_time
      s = IceCube::Schedule.new(base_time)

      dur = event_duration
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
        s.add_exception_time(event_time_zone.parse(exdate.to_s)) if exdate.present?
      end

      Array(data['rdates']).each do |rdate|
        s.add_recurrence_time(event_time_zone.parse(rdate.to_s)) if rdate.present?
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
  end
end