# app/controllers/recurrence_ui/dev/previews_controller.rb
module RecurrenceUi
  module Dev
    class RecurrencePreviewsController < ApplicationController 
      layout "recurrence_ui/dev"          

      def index
        @locales = RecurrenceUi.config.supported_locales
        raw_locale = params[:locale].presence || session[:locale].presence || RecurrenceUi.config.locale&.to_s || I18n.locale&.to_s
        
        # 1. Create in-memory test model (without saving to DB)
        @event = Event.new(
          title: "Team Meeting",
          description: "Gem release discussion",
          recurring_rules: {
            rrules: [
              {
                rule_type: "IceCube::WeeklyRule",
                interval: 1,
                validations: { day: [1, 3, 5] } # Mon, Wed, Fri
              }
            ],
            exdates: [],
            rdates: []
          }
        )
        
        # Test rule cases set (Daily, Weekly, Monthly, Yearly + multi-rules & edge cases)
        @rule_cases = [
          {
            name: "Daily with interval",
            hash: {
              rrules: [
                { rule_type: "IceCube::DailyRule", interval: 3 }
              ]
            }
          },
          {
            name: "Daily with interval (1 day)",
            hash: {
              rrules: [
                { rule_type: "IceCube::DailyRule", interval: 1 }
              ]
            }
          },
          {
            name: "Daily until date",
            hash: {
              rrules: [
                { rule_type: "IceCube::DailyRule", interval: 1, until: "2026-12-31T23:59:59Z" }
              ]
            }
          },
          {
            name: "Every 3 days 1 time only",
            hash: {
              rrules: [
                { rule_type: "IceCube::DailyRule", interval: 3, count: 1 }
              ]
            }
          },
          {
            name: "Every 3 days 2 times only",
            hash: {
              rrules: [
                { rule_type: "IceCube::DailyRule", interval: 3, count: 2 }
              ]
            }
          },
          {
            name: "Weekly on Mon & Wed",
            hash: {
              rrules: [
                { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [1, 3] } }
              ]
            }
          },
          {
            name: "Weekly on Mon & Wed (Interval 2)",
            hash: {
              rrules: [
                { rule_type: "IceCube::WeeklyRule", interval: 2, validations: { day: [1, 3] } }
              ]
            }
          },
          {
            name: "Weekly on Mon & Wed (Interval 5)",
            hash: {
              rrules: [
                { rule_type: "IceCube::WeeklyRule", interval: 5, validations: { day: [1, 3] } }
              ]
            }
          },
          {
            name: "Monthly by weekday (1st & last Mon)",
            hash: {
              rrules: [
                { rule_type: "IceCube::MonthlyRule", interval: 1, validations: { day_of_week: { "1" => [1, -1] } } }
              ]
            }
          },
          { 
            name: "Every month on complex weekdays",
            hash: {
              rrules: [
                {
                  rule_type: "IceCube::MonthlyRule",
                  interval: 1,
                  validations: {
                    day_of_week: { "0" => [1, -1], "1" => [3, 4], "2" => [2, 5], "3" => [1, -1], "4" => [1, 3], "5" => [3, -1], "6" => [2, 5] }
                  }
                }
              ]
            }
          },
          {
            name: "Yearly by day of month in Nov",
            hash: {
              rrules: [
                { rule_type: "IceCube::YearlyRule", interval: 5, validations: { day_of_month: [19], month_of_year: [11] }, until: "2026-09-01T23:59:59Z" }
              ]
            }
          },
          {
            name: "With Exdates",
            hash: {
              rrules: [
                { rule_type: "IceCube::DailyRule", interval: 1 }
              ],
              exdates: ["2026-08-22", "2026-08-28"]
            }
          },
          {  
            name: "Every 3 years in January (Complex weekdays)",
            hash: {
              rrules: [
                {
                  rule_type: "IceCube::YearlyRule",
                  interval: 3,
                  validations: {
                    day_of_week: { "0" => [5, -1], "1" => [3, -1], "2" => [1], "3" => [2], "4" => [1, 5], "6" => [3, -1] },
                    month_of_year: [1]
                  }
                }
              ]
            }
          },
          {  
            name: "Monthly with exdates and rdates",
            hash: {
              rrules: [
                { rule_type: "IceCube::MonthlyRule", interval: 1, validations: { day_of_month: [1, 10, 16, 17] }, until: "2026-07-29T23:59:59Z" }
              ],
              exdates: ["2026-08-19", "2026-08-20"],
              rdates: ["2026-08-26", "2026-08-28"]
            } 
          },

          {
            name: "Multiple Rules (Weekly Mon + Monthly 1st & 15th)",
            hash: {


              rrules: [
                {rule_type: "IceCube::MonthlyRule", interval: 2, validations: {day_of_month: [1, 2, 3, 5, 10, 11, 13, 15, 20, 21, 23, 25, 30]}}, 
                {rule_type: "IceCube::MonthlyRule", interval: 1, validations: {day_of_month: [1, 11, 21, 31]}},
              ],
              exdates: ["2026-09-01"],
              rdates: ["2026-09-10"]
            }
          },
          {
            name: "Multiple Rules (Weekly Mon + Monthly 1st & 15th)",
            hash: {
              rrules: [
                { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [1] } },
                { rule_type: "IceCube::MonthlyRule", interval: 1, validations: { day_of_month: [1, 15] } }
              ],
              exdates: ["2026-09-01"],
              rdates: ["2026-09-10"]
            }
          }
        ]

        # Convert all cases and nested hashes to indifferent access
        @rule_cases = @rule_cases.map(&:with_indifferent_access)

        @context_sources = {
          gem_defaults: {
            title: "1. Gem Defaults",
            file: "lib/recurrence_ui/configuration.rb",
            locale: RecurrenceUi::Configuration::DEFAULT_LOCALE,
            time_zone: RecurrenceUi::Configuration::DEFAULT_TIME_ZONE,
            week_start: RecurrenceUi::Configuration::DEFAULT_WEEK_START,
            note: "Hardcoded base values of the gem as a fallback"
          },
          app_defaults: {
            title: "2. Application Parameters",
            file: "dummy/config/application.rb",
            locale: I18n.default_locale&.to_s,
            time_zone: Rails.application.config.time_zone,
            week_start: (Date.beginning_of_week == :monday ? 1 : 0),
            note: "Global settings of the Rails application itself"
          },
          gem_initializer: {
            title: "3. Gem Parameters in Application",
            file: "dummy/config/initializers/recurrence_ui.rb",
            locale: RecurrenceUi.config.locale&.to_s,
            time_zone: RecurrenceUi.config.time_zone,
            week_start: RecurrenceUi.config.week_start,
            note: "Explicit override of gem parameters via RecurrenceUi.configure"
          },
          session: {
            title: "4. Session Parameters",
            file: "session[:locale], session[:time_zone]...",
            locale: session[:locale].presence,
            time_zone: session[:time_zone].presence,
            week_start: session[:week_start].presence,
            note: "Current user session data"
          },
          url: {
            title: "5. URL Parameters",
            file: "params[:locale], params[:time_zone]...",
            locale: params[:locale].presence,
            time_zone: params[:time_zone].presence,
            week_start: params[:week_start].presence,
            note: "Explicit override from Query String parameters"
          },
          resolved: {
            title: "FINAL RESOLVED (Result)",
            file: "RecurrenceUi.config.resolved_locale",
            locale: RecurrenceUi.config.resolved_locale(raw_locale),
            time_zone: RecurrenceUi.config.resolved_time_zone(params[:time_zone]),
            week_start: RecurrenceUi.config.resolved_week_start(params[:week_start]),
            note: raw_locale == 'fr' ? "Requested 'fr' (unsupported) -> fallback to 'en'" : "Ready for render"
          }
        }

        # Current time to demonstrate time zone handling
        @current_time = Time.now.in_time_zone(@context_sources[:resolved][:time_zone])
      end
             
      private

      def resolve_locale(passed)
        passed.presence || RecurrenceUi.config.resolved_locale
      end

      def resolve_time_zone(passed)
        passed.presence || RecurrenceUi.config.resolved_time_zone
      end

      def resolve_week_start(passed)
        passed.presence || RecurrenceUi.config.resolved_week_start
      end
    end
  end
end