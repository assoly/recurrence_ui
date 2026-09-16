# recurrence_ui/app/models/concerns/recurrence_ui/has_recurrence.rb
module RecurrenceUi
  module HasRecurrence
    extend ActiveSupport::Concern

    included do
      # It's recommended to use JSON/JSONB for storing original data types
      serialize :recurring_rules, type: Hash, coder: YAML
    end

    def recurring_rules=(value)
      if value.is_a?(String) && value.present?
        begin
          value = JSON.parse(value)
        rescue JSON::ParserError => e
          Rails.logger.warn "[RecurrenceUi] Failed to parse recurring_rules JSON: #{e.message}"
          value = nil
        end
      end

      if value.is_a?(Hash) && value.present?
        super(value.deep_stringify_keys)
      else
        super(nil)
      end
    end

    # Returns a full IceCube::Schedule object instead of a single IceCube::Rule
    def schedule(start_time = nil)
      base_time = start_time || self.try(:calendar_datetime)&.to_time || Time.current
      s = IceCube::Schedule.new(base_time)

      return s if recurring_rules.blank?

      data = recurring_rules.deep_dup

      # Support for both a single rule (legacy/simple) and a structure with rrules
      rules_array = data['rrules'] || [data]

      rules_array.each do |rule_hash|
        next if rule_hash.blank? || !rule_hash.is_a?(Hash)

        # 1. Correction 0 -> 7 for IceCube::MonthlyRule (day_of_week)
        if rule_hash['rule_type'] == 'IceCube::MonthlyRule' &&
           rule_hash.dig('validations', 'day_of_week').is_a?(Hash)
          
          rule_hash['validations']['day_of_week'].transform_values! do |days|
            Array(days).map { |day| day.to_i == 0 ? 7 : day.to_i }
          end
        end

        # 2. Restoration of IceCube::Rule
        begin
          r = IceCube::Rule.from_hash(rule_hash)

          # Apply the global repeat_until attribute of the model, if it exists and is not already specified in the rule_hash
          if respond_to?(:repeat_until) && repeat_until.present? && !rule_hash['until']
            r = r.until(repeat_until.to_time.end_of_day)
          end

          s.add_recurrence_rule(r)
        rescue StandardError => e
          Rails.logger.error "[RecurrenceUi] Error building IceCube::Rule from hash: #{e.message}"
        end
      end

      # 3. Adding exceptions (exdates) and additional dates (rdates)
      Array(data['exdates']).each do |exdate|
        s.add_exception_time(Time.zone.parse(exdate.to_s)) if exdate.present?
      end

      Array(data['rdates']).each do |rdate|
        s.add_recurrence_time(Time.zone.parse(rdate.to_s)) if rdate.present?
      end

      s
    end

    # Save the rule method for backward compatibility (returns the first rule from the schedule)
    def rule
      schedule.recurrence_rules.first
    end

    # Next upcoming occurrences
    def upcoming_occurrences(limit = 5, from_time = Time.current.beginning_of_day)
      schedule.next_occurrences(limit, from_time)
    end

    # Description of the rule / schedule
    def recurring_text
      return I18n.t("recurrence_ui.once", default: "Once") if recurring_rules.blank?
      
      # IceCube::Schedule#to_s collects the textual description of the schedule
      schedule.to_s
    end
  end
end