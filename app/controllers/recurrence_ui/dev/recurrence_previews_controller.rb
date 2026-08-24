# app/controllers/recurrence_ui/dev/previews_controller.rb
module RecurrenceUi
    module Dev
        class RecurrencePreviewsController < ApplicationController 
            layout "recurrence_ui/dev"          
            def index
                @locales = RecurrenceUi.config.supported_locales
                raw_locale = params[:locale].presence || session[:locale].presence || RecurrenceUi.config.locale&.to_s || I18n.locale&.to_s
                # 1. Создаем тестовую модель прямо в памяти (без сохранения в БД)
                @event = Event.new(
                title: "Встреча команды",
                description: "Обсуждение релиза гема",
                recurring_rules: {
                    rule_type: "IceCube::WeeklyRule",
                    interval: 1,
                    validations: { day: [1, 3, 5] } # Пн, Ср, Пт
                }
                )
                
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
                    name: "Every month on: 1st and last Sunday; 3rd and 4th Monday; 2nd and 5th Tuesday; 1st and last Wednesday; 1st and 3rd Thursday; 3rd and last Friday; 2nd and 5th Saturday",
                    hash: {"rule_type":"IceCube::MonthlyRule","interval":1,"validations":{"day_of_week":{"0":[1,-1],"1":[3,4],"2":[2,5],"3":[1,-1],"4":[1,3],"5":[3,-1],"6":[2,5]}}}
                    },
                    {
                    name: "Yearly by day of month in Nov",
                    hash: { rule_type: "IceCube::YearlyRule", interval: 5, validations: { day_of_month: [19], month_of_year: [11] }, until: "2026-09-01T23:59:59Z" }
                    },
                    {
                    name: "With Exdates",
                    hash: { rule_type: "IceCube::DailyRule", interval: 1, exdates: ["2026-08-22", "2026-08-28"] }
                    },
                    {  
                    name: "Every 3 years in January: 5th and last Sunday; 3rd and last Monday; 1st Tuesday; 2nd Wednesday; 1st and 5th Thursday; 3rd and last Saturday",
                    hash:  {"rule_type":"IceCube::YearlyRule","interval":3,"validations":{"day_of_week":{"0":[5,-1],"1":[3,-1],"2":[1],"3":[2],"4":[1,5],"6":[3,-1]},"month_of_year":[1]}}
                    },
                    {  
                    name: "Every month on: on the 1st, 10th, 16th, and 17th until 29 July 2026 Exceptions: 19 August 2026, 20 August 2026 Additional Dates: 26 August 2026, 28 August 2026",
                    hash:  {"rule_type"=>"IceCube::MonthlyRule", "interval"=>1, "validations"=>{"day_of_month"=>[1, 10, 16, 17]}, "exdates"=>["2026-08-19", "2026-08-20"], "rdates"=>["2026-08-26", "2026-08-28"], "until"=>"2026-07-29T23:59:59Z"} 
                    }
                ]
                # Приводим все кейсы и их вложенные хэши к indifferent access
                @rule_cases = @rule_cases.map(&:with_indifferent_access)
                @context_sources = {
                    gem_defaults: {
                        title: "1. Дефолты гема",
                        file: "lib/recurrence_ui/configuration.rb",
                        locale: RecurrenceUi::Configuration::DEFAULT_LOCALE,
                        time_zone: RecurrenceUi::Configuration::DEFAULT_TIME_ZONE,
                        week_start: RecurrenceUi::Configuration::DEFAULT_WEEK_START,
                        note: "Зашитые базовые значения гема на крайний случай"
                    },
                    app_defaults: {
                        title: "2. Параметры приложения",
                        file: "dummy/config/application.rb",
                        locale: I18n.default_locale&.to_s,
                        time_zone: Rails.application.config.time_zone,
                        week_start: (Date.beginning_of_week == :monday ? 1 : 0),
                        note: "Глобальные настройки самого Rails-приложения"
                    },
                    gem_initializer: {
                        title: "3. Параметры гема в приложении",
                        file: "dummy/config/initializers/recurrence_ui.rb",
                        locale: RecurrenceUi.config.locale&.to_s,
                        time_zone: RecurrenceUi.config.time_zone,
                        week_start: RecurrenceUi.config.week_start,
                        note: "Точечное переопределение параметров гема через RecurrenceUi.configure"
                    },
                    session: {
                        title: "4. Параметры в сессии",
                        file: "session[:locale], session[:time_zone]...",
                        locale: session[:locale].presence,
                        time_zone: session[:time_zone].presence,
                        week_start: session[:week_start].presence,
                        note: "Данные текущей пользовательской сессии"
                    },
                    url: {
                        title: "5. Параметры в URL",
                        file: "params[:locale], params[:time_zone]...",
                        locale: params[:locale].presence,
                        time_zone: params[:time_zone].presence,
                        week_start: params[:week_start].presence,
                        note: "Явный перехват из Query String адресной строки"
                    },
                    resolved: {
                        title: "FINAL RESOLVED (Результат)",
                        file: "RecurrenceUi.config.resolved_locale",
                        locale: RecurrenceUi.config.resolved_locale(raw_locale), # вернет 'en'
                        time_zone: RecurrenceUi.config.resolved_time_zone(params[:time_zone]),
                        week_start: RecurrenceUi.config.resolved_week_start(params[:week_start]),
                        note: raw_locale == 'fr' ? "Запрошен 'fr' (не поддерживается) -> сброшено на 'en'" : "Готово к рендеру"
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