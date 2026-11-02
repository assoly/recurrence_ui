# recurrence_ui/lib/generators/recurrence_ui/install/install_generator.rb
module RecurrenceUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecurrenceUi JavaScript integration into the application"

      def register_controller
        app_js_path = Rails.root.join("app/javascript/application.js")
        
        if File.exist?(app_js_path)
          unless File.read(app_js_path).include?("recurrence_ui")
            append_to_file "app/javascript/application.js", <<~JS

              // Register RecurrenceUi Stimulus controller
              import { registerRecurrenceUiController } from "recurrence_ui"
              registerRecurrenceUiController(application)
            JS
            say "Added RecurrenceUi registration to app/javascript/application.js", :green
          else
            say "RecurrenceUi is already registered in app/javascript/application.js", :yellow
          end
        else
          say "Could not find app/javascript/application.js. Please register RecurrenceUi manually.", :red
        end
      end
    end
  end
end