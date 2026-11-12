# config/initializers/recurrence_ui.rb

RecurrenceUi.configure do |config|
  # General settings
  config.locale = :ru
  config.time_zone = "Europe/Moscow"
  config.week_start = 1

  # Default event settings
  config.start_time = "06:00"
  config.end_time = "16:00"
  config.duration = 3600

  # UI options
  config.allow_multiple_rules = true
  config.show_duration = true
  config.show_start_date_time = true
  config.show_time_zone = true
  config.show_end_date_time = true
  config.show_exceptions = true
  config.show_rdates = true
  config.show_termination = true

  # Enabled recurrence rule types
  config.enabled_rule_types = %w[
    never
    weekly
    daily
    monthly_by_day_of_month
  ]
end