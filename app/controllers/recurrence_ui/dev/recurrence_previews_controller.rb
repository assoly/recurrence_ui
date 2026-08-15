# app/controllers/recurrence_ui/dev/previews_controller.rb
module RecurrenceUi
    module Dev
        class RecurrencePreviewsController < ActionController::Base  
            layout "recurrence_ui/dev"          
            def index
                @locales = [:en, :ru, :ja]
                
                # Набор тестовых правил (Daily, Weekly, Monthly, Yearly + крайние случаи)
                @rule_cases = [
                    {
                    name: "Daily with interval",
                    hash: { rule_type: "IceCube::DailyRule", interval: 3 }
                    },
                    {
                    name: "Daily with interval",
                    hash: { rule_type: "IceCube::DailyRule", interval: 1 }
                    },
                    {
                    name: "Daily until date",
                    hash: { rule_type: "IceCube::DailyRule", interval: 1, until: "2026-12-31T23:59:59Z" }
                    },
                    {
                    name: "Weekly on Mon & Wed",
                    hash: { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [1, 3] } }
                    },
                    {
                    name: "Weekly on Mon & Wed",
                    hash: { rule_type: "IceCube::WeeklyRule", interval: 2, validations: { day: [1, 3] } }
                    },
                    {
                    name: "Weekly on Mon & Wed",
                    hash: { rule_type: "IceCube::WeeklyRule", interval: 5, validations: { day: [1, 3] } }
                    },
                    {
                    name: "Monthly by weekday (1st & last Mon)",
                    hash: { rule_type: "IceCube::MonthlyRule", interval: 1, validations: { day_of_week: { "1" => [1, -1] } } }
                    },
                    {
                    name: "Yearly by day of month in Nov",
                    hash: { rule_type: "IceCube::YearlyRule", interval: 5, validations: { day_of_month: [19], month_of_year: [11] }, until: "2026-09-01T23:59:59Z" }
                    },
                    {
                    name: "With Exdates",
                    hash: { rule_type: "IceCube::DailyRule", interval: 1, exdates: ["2026-08-22", "2026-08-28"] }
                    }
                ]
            end
        end
    end

end