module RecurrenceUi
  module HasRecurrence
    extend ActiveSupport::Concern

    included do
      # Class attributes for storing model field name configuration
      class_attribute :recurrence_rules_field,      default: RecurrenceUi.config.default_recurring_rules_field
      class_attribute :recurrence_start_time_field, default: RecurrenceUi.config.default_start_time_field
      class_attribute :recurrence_end_time_field,   default: RecurrenceUi.config.default_end_time_field
      class_attribute :recurrence_time_zone_field,  default: RecurrenceUi.config.default_time_zone_field
      class_attribute :recurrence_duration_field,   default: RecurrenceUi.config.default_duration_field
      attr_accessor :form_start_date, :form_start_time, 
                    :form_duration_mode, :form_duration_days, :form_duration_hours, :form_duration_minutes, 
                    :form_end_date, :form_end_time

      before_save :process_recurrence_time_attributes
    end

    class_methods do
      # DSL method to configure model recurrence and time fields.
      #
      # @param rules [Symbol, String, nil] Field name for storing rules (JSON/Hash).
      # @param start_time [Symbol, String, nil] Field name for start date/time.
      # @param end_time [Symbol, String, nil] Field name for end date/time.
      # @param time_zone [Symbol, String, nil] Field name for time zone.
      # @param duration [Symbol, String, nil] Field name for duration in seconds.
      # @return [void]
      def has_recurrence(rules: nil, start_time: nil, end_time: nil, time_zone: nil, duration: nil)
        self.recurrence_rules_field      = rules      if rules.present?
        self.recurrence_start_time_field = start_time if start_time.present?
        self.recurrence_end_time_field   = end_time   if end_time.present?
        self.recurrence_time_zone_field  = time_zone  if time_zone.present?
        self.recurrence_duration_field   = duration   if duration.present?

        field_name = recurrence_rules_field.to_s

        # READ: Returns a Hash containing rules and UI metadata
        define_method(field_name) do
          raw_val = read_attribute(field_name)
          
          # What radio button mode was selected in the form? 'duration' or 'end_at'
          return { 'form_duration_mode' => 'duration', 'rrules' => [] }.with_indifferent_access if raw_val.blank?

          parsed = if raw_val.is_a?(Hash)
                     raw_val.with_indifferent_access
                   elsif raw_val.is_a?(String)
                     JSON.parse(raw_val).with_indifferent_access rescue {}
                   else
                     {}
                   end

          # Ensure that the form_duration_mode key is always present, defaulting to 'duration' if missing
          parsed[:form_duration_mode] ||= 'duration'
          parsed
        end

        # WRITE: Accepts a Hash or JSON string and stores it in the database (it could contain both rules and UI metadata)
        define_method("#{field_name}=") do |value|
          parsed_value = case value
                         when String
                           JSON.parse(value) rescue {}
                         when Hash, ActionController::Parameters
                           value.to_h
                         else
                           {}
                         end

          write_attribute(field_name, parsed_value.deep_stringify_keys)
        end
      end

    # Method to return the list of permitted parameters for recurrence fields, useful for strong parameters in controllers.
      def recurrence_permitted_params
        [
          recurrence_rules_field.to_sym,
          recurrence_start_time_field.to_sym,
          recurrence_end_time_field.to_sym,
          recurrence_time_zone_field.to_sym,
          recurrence_duration_field.to_sym,
          :form_start_date,
          :form_start_time,
          :form_duration_mode,
          :form_duration_days,
          :form_duration_hours,
          :form_duration_minutes,
          :form_end_date,
          :form_end_time
        ]
      end
    
    end
    # Returns a RecurrenceFormatterService instance for formatting recurrence data.
    # @param options [Hash] Options to customize formatting (e.g., :zone_type, :show_zone)
    # @return [RecurrenceFormatterService]    
    def summary(options = {})
      RecurrenceFormatterService.new(self, options)
    end



    # --- Instance Methods ---
    # Returns the raw recurrence rules stored in the model, which may include both recurrence rules and UI metadata.
    # @return [Hash] The raw recurrence rules hash.
    def recurrence_raw_rules
      public_send(self.class.recurrence_rules_field)
    end
    
    # Returns the event's time zone, either from the model's time zone field or falling back to the application's default time zone.
    # @return [ActiveSupport::TimeZone] The time zone for the event.
    def event_time_zone
      tz_name = if self.class.recurrence_time_zone_field &&
                  respond_to?(self.class.recurrence_time_zone_field)
                  public_send(self.class.recurrence_time_zone_field)
                end
      # If the time zone name is not present (nil or empty string), safely return the application's Time.zone
      return Time.zone unless tz_name.present?

      ActiveSupport::TimeZone[tz_name] || Time.zone || ActiveSupport::TimeZone[Rails.application.config.time_zone]
    end

    # Returns the recurrence start time in the event's time zone, defaulting to Time.current if not set.
    # @return [ActiveSupport::TimeWithZone] The start time of the recurrence.
    def recurrence_start_time
      raw_start = nil
      if self.class.recurrence_start_time_field && respond_to?(self.class.recurrence_start_time_field)
        raw_start = public_send(self.class.recurrence_start_time_field)
      end
      (raw_start || Time.current).in_time_zone(event_time_zone)
    end

    # Returns the recurrence end time in the event's time zone, or nil if not set.
    # @return [ActiveSupport::TimeWithZone, nil] The end time of the recurrence, or nil if not set.
    def recurrence_end_time
      end_field = self.class.recurrence_end_time_field
      return nil unless end_field && respond_to?(end_field)

      raw_end = public_send(end_field)
      return nil unless raw_end.present?

      raw_end.in_time_zone(event_time_zone)
    end

    # Returns the recurrence start time in the specified time zone type (:event, :application, or a specific zone name).
    # @param zone_type [Symbol, String] The type of time zone to convert to (:event, :application, or a specific zone name).
    # @return [ActiveSupport::TimeWithZone] The start time of the recurrence in the specified time zone.
    def start_time_in_zone(zone_type = :event)
      time_in_zone(recurrence_start_time, zone_type)
    end

    # Returns the recurrence end time in the specified time zone type (:event, :application, or a specific zone name).
    # @param zone_type [Symbol, String] The type of time zone to convert to (:event, :application, or a specific zone name).
    # @return [ActiveSupport::TimeWithZone, nil] The end time of the recurrence in the specified time zone, or nil
    def end_time_in_zone(zone_type = :event)
      time_in_zone(recurrence_end_time, zone_type)
    end

    # Returns the current duration of the recurrence in seconds, based on the model's duration field.
    # @return [Integer] The duration in seconds, or 0 if not set or invalid.
    def current_duration_seconds
      dur_field = self.class.recurrence_duration_field
      if dur_field && respond_to?(dur_field)
        val = public_send(dur_field)
        return val.to_i if val.present? && val.to_i > 0
      end
      0
    end
   

    # --- Building IceCube::Schedule ---
    # Returns an IceCube::Schedule object based on the stored recurrence rules and start time.
    # @param start_time_override [Time, nil] Optional override for the start time of the schedule.
    # @return [IceCube::Schedule] The IceCube schedule object representing the recurrence rules.
    def schedule(start_time_override = nil)
      base_time = start_time_override || recurrence_start_time
      s = IceCube::Schedule.new(base_time)

      dur = current_duration_seconds
      s.duration = dur if dur > 0

      raw_data = recurrence_raw_rules
      return s if raw_data.blank?

      # Превращаем в хэш с строковыми ключами на всякий случай
      raw_data = raw_data.deep_stringify_keys if raw_data.is_a?(Hash)

      # Достаем массив правил безопасно, игнорируя UI-ключи типа form_duration_mode
      rules_array = raw_data['rrules'] || (raw_data['rule_type'] ? [raw_data] : [])

      rules_array.each do |rule_hash|
        next if rule_hash.blank? || !rule_hash.is_a?(Hash)

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

      Array(raw_data['exdates']).each do |exdate|
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

      Array(raw_data['rdates']).each do |rdate|
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

    # Returns the next occurrences of the event based on the schedule, limited to a specified number and starting from a given time.
    # @param limit [Integer] The maximum number of occurrences to return.
    # @param from_time [Time] The time from which to start looking for occurrences.
    # @return [Array<Time>] An array of the next occurrence times in the event's time zone.
    def upcoming_occurrences(limit = 5, from_time = Time.current)
      schedule.next_occurrences(limit, from_time.in_time_zone(event_time_zone))
    end

    # Returns the next occurrences of the event in a specified time zone, limited to a specified number and starting from a given time.
    # @param limit [Integer] The maximum number of occurrences to return.
    # @param from_time [Time] The time from which to start looking for occurrences.
    # @param zone_type [Symbol, String] The type of time zone to convert to (:event, :application, or a specific zone name).
    # @return [Array<Time>] An array of the next occurrence times in the specified time zone.
    def upcoming_occurrences_in_zone(limit = 5, from_time = Time.current, zone_type = :event)
      target_zone = resolve_zone_type(zone_type)
      schedule.next_occurrences(limit, from_time.in_time_zone(target_zone))
    end

    # Returns the first occurrence of the event based on the schedule.
    # @return [Time, nil] The time of the first occurrence in the event's time zone, or nil if there are no occurrences.
    def first_occurrence
      schedule.first    
    end

    # Returns the rule object for the first recurrence rule in the schedule, if any.
    # @return [IceCube::Rule, nil] The first recurrence rule, or nil if there are no rules.
    def rule
      schedule.recurrence_rules.first
    end

    # Delegate formatting methods to the summary service
    delegate :formatted_start_time, :formatted_end_time, :formatted_duration, :formatted_upcoming_occurrences, :to_s, to: :summary

    private
    
    # Returns the given time in the specified time zone type (:event, :application, or a specific zone name).
    # @param time [Time, nil] The time to convert.
    # @param zone_type [Symbol, String] The type of time zone to convert to (:event, :application, or a specific zone name).
    # @return [ActiveSupport::TimeWithZone, nil] The time in the specified time zone, or nil if the input time is nil.
    def time_in_zone(time, zone_type = :event)
      return nil unless time

      target_zone = resolve_zone_type(zone_type)
      time.in_time_zone(target_zone)
    end

    # Processes the form attributes related to recurrence time and updates the model's fields accordingly.
    # This method is called before saving the record to ensure that the recurrence start time, end time, and duration are correctly calculated and stored based on the form inputs.
    def process_recurrence_time_attributes
      tz = event_time_zone

      if respond_to?(:form_start_date=) && form_start_date.present?
        time_str = form_start_time.presence || '09:00'
        parsed_start = tz.parse("#{form_start_date} #{time_str}")
        write_attribute(self.class.recurrence_start_time_field, parsed_start) if parsed_start
      end

      start_val = public_send(self.class.recurrence_start_time_field)
      return unless start_val.present?

      dur_field = self.class.recurrence_duration_field
      end_field = self.class.recurrence_end_time_field

      # Получаем текущий хэш (он уже содержит и правила, и метаданные)
      current_rules = recurrence_raw_rules.deep_dup

      # Сохраняем выбранный в форме режим в общие метаданные правил
      if form_duration_mode.present?
        current_rules[:form_duration_mode] = form_duration_mode
      end

      if form_duration_mode == 'end_at' && form_end_date.present?
        end_time_str = form_end_time.presence || '09:00'
        parsed_end = tz.parse("#{form_end_date} #{end_time_str}")

        if parsed_end.present?
          write_attribute(end_field, parsed_end) if read_attribute(end_field) != parsed_end
          calculated_dur = (parsed_end - start_val).to_i
          write_attribute(dur_field, calculated_dur) if dur_field && respond_to?("#{dur_field}=") && read_attribute(dur_field) != calculated_dur
        end
      else
        days    = form_duration_days.to_i
        hours   = form_duration_hours.to_i
        minutes = form_duration_minutes.to_i
        total_seconds = (days * 1.day + hours * 1.hour + minutes * 1.minute).to_i
        total_seconds = 1.hour if total_seconds <= 0

        write_attribute(dur_field, total_seconds) if dur_field && respond_to?("#{dur_field}=") && read_attribute(dur_field) != total_seconds

        calculated_end = start_val + total_seconds.seconds
        write_attribute(end_field, calculated_end) if end_field && respond_to?("#{end_field}=") && read_attribute(end_field) != calculated_end
      end

      # Записываем обновленный хэш (вместе с form_duration_mode) обратно через наш сеттер
      public_send("#{self.class.recurrence_rules_field}=", current_rules)
    end
    
    # Resolves the appropriate time zone based on the provided zone type.
    # @param zone_type [Symbol, String] The type of time zone to resolve (:event, :application, or a specific zone name).
    # @return [ActiveSupport::TimeZone] The resolved time zone object.
    def resolve_zone_type(zone_type)
      case zone_type
      when :event
        event_time_zone
      when :application, :app
        Time.zone
      else
        Time.find_zone(zone_type) || Time.zone
      end
    end
  end
end