# recurrence_ui/app/services/recurrence_ui/event_formatter.rb
module RecurrenceUi
  class EventFormatter
    def initialize(record, zone_type: :event, locale: I18n.locale)
      @record = record
      @zone_type = zone_type
      @locale = locale
    end

   def formatted_start_time(format = :default)
      time = @record.start_time_in_zone(@zone_type)
     return "—" unless time
   
     I18n.with_locale(@locale) { I18n.l(time, format: format) }
    end

    def formatted_end_time(format = :default)
      time = @record.end_time_in_zone(@zone_type)
      return "—" unless time

      I18n.with_locale(@locale) { I18n.l(time, format: format) }
    end

    def formatted_upcoming_occurrences(limit = 5, format = :default)
      occurrences = @record.upcoming_occurrences(limit, @zone_type)
      return [] if occurrences.empty?

      I18n.with_locale(@locale) do
        occurrences.map do |occ|
          {
            start_time: I18n.l(occ.start_time, format: format),
            end_time: occ.end_time ? I18n.l(occ.end_time, format: format) : nil
          }
        end
      end
    end
  end
end