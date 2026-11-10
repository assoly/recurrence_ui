module RecurrenceUi
  module HasRecurrence
    extend ActiveSupport::Concern

    included do
      # Только поле правил имеет разумный дефолт, остальные по умолчанию nil (отключены)
      class_attribute :recurrence_rules_field,      default: :recurring_rules
      class_attribute :recurrence_start_time_field, default: nil
      class_attribute :recurrence_end_time_field,   default: nil
      class_attribute :recurrence_time_zone_field,  default: nil
      class_attribute :recurrence_duration_field,   default: nil

      attr_accessor :form_start_date, :form_start_time, 
                    :form_duration_mode, :form_duration_days, :form_duration_hours, :form_duration_minutes, 
                    :form_end_date, :form_end_time

      before_save :process_recurrence_time_attributes
    end

    class_methods do
      # DSL для явной конфигурации полей модели.
      def has_recurrence(rules: nil, start_time: nil, end_time: nil, time_zone: nil, duration: nil)
        self.recurrence_rules_field      = rules      if rules.present?
        self.recurrence_start_time_field = start_time if start_time.present?
        self.recurrence_end_time_field   = end_time   if end_time.present?
        self.recurrence_time_zone_field  = time_zone  if time_zone.present?
        self.recurrence_duration_field   = duration   if duration.present?

        field_name = recurrence_rules_field.to_s

        define_method(field_name) do
          raw_val = safe_read_attribute(field_name)
          return { 'form_duration_mode' => 'duration', 'rrules' => [] }.with_indifferent_access if raw_val.blank?

          parsed = if raw_val.is_a?(Hash)
                     raw_val.with_indifferent_access
                   elsif raw_val.is_a?(String)
                     JSON.parse(raw_val).with_indifferent_access rescue {}
                   else
                     {}
                   end

          parsed[:form_duration_mode] ||= 'duration'
          parsed
        end

        define_method("#{field_name}=") do |value|
          parsed_value = case value
                         when String
                           JSON.parse(value) rescue {}
                         when Hash, ActionController::Parameters
                           value.to_h
                         else
                           {}
                         end

          safe_write_attribute(field_name, parsed_value.deep_stringify_keys)
        end
      end

      def recurrence_permitted_params
        params = [recurrence_rules_field.to_sym]
        params << recurrence_start_time_field.to_sym if recurrence_start_time_field.present?
        params << recurrence_end_time_field.to_sym if recurrence_end_time_field.present?
        params << recurrence_time_zone_field.to_sym if recurrence_time_zone_field.present?
        params << recurrence_duration_field.to_sym if recurrence_duration_field.present?
        
        params + [
          :form_start_date, :form_start_time,
          :form_duration_mode, :form_duration_days, :form_duration_hours, :form_duration_minutes,
          :form_end_date, :form_end_time
        ]
        end
      end

      def summary(options = {})
        RecurrenceFormatterService.new(self, options)
      end

      # --- Instance Methods с защитой от отсутствующих полей ---

      def recurrence_raw_rules
        public_send(self.class.recurrence_rules_field)
      end
    
          # Определяет часовой пояс события.
      def event_time_zone
        tz_name = nil

        # Если поле таймзоны настроено через has_recurrence и существует у модели
        attr = self.class.recurrence_time_zone_field
        if attr.present?
          tz_name = public_send(attr) if respond_to?(attr)
        end

        # Фоллбэки: значение из поля -> таймзона приложения -> глобальный конфиг Rails
        zone_name = tz_name.presence || Time.zone&.name
        ActiveSupport::TimeZone[zone_name] || Time.zone || ActiveSupport::TimeZone[Rails.application.config.time_zone]
      end

    
      def recurrence_start_time
        attr = self.class.recurrence_start_time_field
        return nil unless attr.present?

        raw_start = safe_read_attribute(attr)
        return nil unless raw_start.present? # <--- если в базе пусто, возвращаем nil

        raw_start.in_time_zone(event_time_zone)
      end

      def recurrence_end_time #возвращает Time в часовом поясе события, либо nil, если поле не настроено или не существует у модели
        attr = self.class.recurrence_end_time_field
        return nil unless attr.present?

        raw_end = safe_read_attribute(attr)
        return nil unless raw_end.present?

        raw_end.in_time_zone(event_time_zone)
      end

      def start_time_in_zone(zone_type = :event)
        return nil unless recurrence_start_time
        time_in_zone(recurrence_start_time, zone_type)
      end

      def end_time_in_zone(zone_type = :event)
        return nil unless recurrence_end_time
        time_in_zone(recurrence_end_time, zone_type)
      end

    def current_duration_seconds
      attr = self.class.recurrence_duration_field
      return nil unless attr.present? && respond_to?(attr)

      val = safe_read_attribute(attr)
      val.present? ? val.to_i : nil # Возвращаем nil, если в базе пусто, а не 0
    end

    # Сборка IceCube (остается без изменений, так как опирается на безопасные методы выше)
    def schedule(start_time_override = nil)
      base_time = start_time_override || recurrence_start_time || Time.current.in_time_zone(event_time_zone)
      s = IceCube::Schedule.new(base_time)

      dur = current_duration_seconds
      s.duration = dur if dur.present? && dur > 0

      raw_data = recurrence_raw_rules
      return s if raw_data.blank?

      raw_data = raw_data.deep_stringify_keys if raw_data.is_a?(Hash)
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

        exact_datetime = base_time.change(year: parsed_date.year, month: parsed_date.month, day: parsed_date.day)
        s.add_exception_time(exact_datetime)
      end

      Array(raw_data['rdates']).each do |rdate|
        next if rdate.blank?
        parsed_date = Date.parse(rdate.to_s) rescue nil
        next unless parsed_date

        exact_datetime = base_time.change(year: parsed_date.year, month: parsed_date.month, day: parsed_date.day)
        s.add_recurrence_time(exact_datetime)
      end

      s
    end

    def upcoming_occurrences(limit = 5, from_time = Time.current)
      schedule.next_occurrences(limit, from_time.in_time_zone(event_time_zone))
    end

    def upcoming_occurrences_in_zone(limit = 5, from_time = Time.current, zone_type = :event)
      target_zone = resolve_zone_type(zone_type)
      schedule.next_occurrences(limit, from_time.in_time_zone(target_zone))
    end

    def first_occurrence
      schedule.first    
    end

    def rule
      schedule.recurrence_rules.first
    end

    delegate :formatted_start_time, :formatted_end_time, :formatted_duration, :formatted_upcoming_occurrences, :to_s, to: :summary

    private

    # --- Приватные методы безопасности (Safe Attributes) ---

    def recurrence_attribute_present?(field_name)
      return false if field_name.blank?
      respond_to?(field_name) && (respond_to?(:has_attribute?) ? has_attribute?(field_name) : true)
    end

    def safe_read_attribute(field_name)
      return nil unless recurrence_attribute_present?(field_name)
      has_attribute?(field_name) ? read_attribute(field_name) : public_send(field_name)
    rescue StandardError
      nil
    end

    def safe_write_attribute(field_name, value)
      return false unless recurrence_attribute_present?(field_name)

      if respond_to?(:write_attribute) && has_attribute?(field_name)
        write_attribute(field_name, value) if read_attribute(field_name) != value
      elsif respond_to?("#{field_name}=")
        public_send("#{field_name}=", value)
      end
      rescue StandardError => e
      Rails.logger.warn("[RecurrenceUi] Could not write to attribute #{field_name}: #{e.message}")
      false
    end

    def time_in_zone(time, zone_type = :event)
      return nil unless time
      target_zone = resolve_zone_type(zone_type)
      time.in_time_zone(target_zone)
    end

    def process_recurrence_time_attributes
      tz = event_time_zone

      if respond_to?(:form_start_date=) && form_start_date.present?
        time_str = form_start_time.presence || '09:00'
        parsed_start = tz.parse("#{form_start_date} #{time_str}")
        safe_write_attribute(self.class.recurrence_start_time_field, parsed_start) if parsed_start
      end

      start_val = recurrence_start_time
      return unless start_val.present?

      dur_field = self.class.recurrence_duration_field
      end_field = self.class.recurrence_end_time_field

      current_rules = recurrence_raw_rules.deep_dup

      if form_duration_mode.present?
        current_rules[:form_duration_mode] = form_duration_mode
      end

      if form_duration_mode == 'end_at' && form_end_date.present?
        end_time_str = form_end_time.presence || DEFAULT_END_TIME
        parsed_end = tz.parse("#{form_end_date} #{end_time_str}")

        if parsed_end.present?
          safe_write_attribute(end_field, parsed_end)
          calculated_dur = (parsed_end - start_val).to_i
          safe_write_attribute(dur_field, calculated_dur)
        end
      else
        days    = form_duration_days.to_i
        hours   = form_duration_hours.to_i
        minutes = form_duration_minutes.to_i
        total_seconds = (days * 1.day + hours * 1.hour + minutes * 1.minute).to_i
        total_seconds = 1.hour if total_seconds <= 0

        safe_write_attribute(dur_field, total_seconds)

        calculated_end = start_val + total_seconds.seconds
        safe_write_attribute(end_field, calculated_end)
      end

      public_send("#{self.class.recurrence_rules_field}=", current_rules)
    end

    def resolve_zone_type(zone_type)
      zone_type = :application if event_time_zone.nil?
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