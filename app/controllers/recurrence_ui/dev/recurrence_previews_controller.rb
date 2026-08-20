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
                    name: "Every 3 days 1 time only",
                    hash:  {rule_type:"IceCube::DailyRule", interval: 3, count: 1} 
                    },
                    {
                    name: "Every 3 days 2 times only",
                    hash:  {rule_type:"IceCube::DailyRule", interval: 3, count: 2} 
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
                @context_sources = {
                    url: {
                        title: "URL Parameters (params)",
                        locale: params[:locale],
                        time_zone: params[:time_zone],
                        week_start: params[:week_start]
                    },
                    session: {
                        title: "Session (session)",
                        locale: session[:locale],
                        time_zone: session[:time_zone],
                        week_start: session[:week_start]
                    },
                    app: {
                        title: "Rails Application (I18n / Time.zone)",
                        locale: I18n.locale&.to_s,
                        time_zone: Time.zone&.name,
                        # Приводим к числу: 0 - Воскресенье, 1 - Понедельник
                        week_start: (Date.beginning_of_week == :sunday ? 0 : 1)
                        },
                    gem: {
                        title: "Gem Configuration (RecurrenceUi.config)",
                        locale: RecurrenceUi.config.locale,
                        time_zone: RecurrenceUi.config.time_zone,
                        week_start: RecurrenceUi.config.week_start
                    },
                    resolved: {
                        title: "FINAL RESOLVED (Результат)",
                        locale: resolve_locale(params[:locale] || session[:locale]),
                        time_zone: resolve_time_zone(params[:time_zone] || session[:time_zone]),
                        week_start: resolve_week_start(params[:week_start] || session[:week_start])
                    }
                }

                # Текущее время для наглядности работы часового пояса
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