# config/initializers/recurrence_ui.rb

RecurrenceUi.configure do |config|
  # General settings
  config.locale = :en # Default locale for the RecurrenceUi component. Supported locales: :en, :uk, :ja, :ru, :be
  config.time_zone = "Asia/Tokyo"
  config.week_start = 0 # 0 = Sunday, 1 = Monday

  # Default event settings
  config.start_time = "06:00" # Default start time for events, string in "HH:MM" format
  config.end_time = "16:00" # Default end time for events, string in "HH:MM" format
  config.duration = 3600 # Default duration for events in seconds (1 hour = 3600 seconds)

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
    monthly_by_day_of_month
    weekly
    daily
    monthly_by_day_of_week]

  # Supported rule types for the recurrence UI
  #config.supported_rule_types = %w[
  #  daily
  #  weekly
  #  monthly_by_day_of_month
  #  monthly_by_day_of_week
  #  yearly_by_day_of_month
  #  yearly_by_day_of_week
  #]
end