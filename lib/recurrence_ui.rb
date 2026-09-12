require "rails"
require "view_component" 
require "ice_cube" # This gem is used to generate recurrence rules and calculate occurrences of events based on those rules.
require "rails-i18n" # This gem is used for internationalization and localization of the application.

require "recurrence_ui/version"
require "recurrence_ui/configuration"
require "recurrence_ui/engine"

module RecurrenceUi
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def config
      configuration
    end
  end
end

