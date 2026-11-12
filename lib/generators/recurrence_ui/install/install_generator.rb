module RecurrenceUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecurrenceUi Stimulus controller registration and Tailwind CSS styles"

      def register_controller
        say "1. Installing RecurrenceUi Stimulus controller registration", :green

        app_js_path = Rails.root.join("app/javascript/application.js")

        unless File.exist?(app_js_path)
          say "Could not find app/javascript/application.js. Please register RecurrenceUi manually.", :red
          return
        end

        content = File.read(app_js_path)
        additions = []

        application_import = 'import { application } from "controllers/application"'
        recurrence_import = 'import { registerRecurrenceUiController } from "recurrence_ui"'
        recurrence_registration = "registerRecurrenceUiController(application)"

        unless content.include?(application_import)
          additions << application_import
        end

        unless content.include?(recurrence_import)
          additions << recurrence_import
        end

        unless content.include?(recurrence_registration)
          additions << recurrence_registration
        end

        if additions.empty?
          say "RecurrenceUi controller is already registered", :blue
        else
          append_to_file app_js_path, "\n\n#{additions.join("\n")}\n"
          say "Added RecurrenceUi controller registration to application.js", :green
        end
      end

      def register_styles
        say "2. Installing RecurrenceUi Tailwind CSS styles", :green

        tailwind_css_paths = [
          Rails.root.join("app/assets/tailwind/application.css"),
          Rails.root.join("app/assets/stylesheets/application.tailwind.css"),
          Rails.root.join("app/assets/stylesheets/application.css")
        ]

        target_css = tailwind_css_paths.find { |path| File.exist?(path) }

        unless target_css
          say 'Tailwind CSS file not found. Please add `@import "recurrence_ui/application.css";` manually.', :yellow
          return
        end

        content = File.read(target_css)
        import_line = '@import "recurrence_ui/application.css";'

        if content.include?(import_line)
          say "RecurrenceUi styles are already imported in #{target_css.relative_path_from(Rails.root)}", :blue
          return
        end

        if content.include?('@import "tailwindcss";')
          inject_into_file target_css, "\n#{import_line}", after: '@import "tailwindcss";'
        else
          prepend_to_file target_css, "#{import_line}\n"
        end

        say "Added RecurrenceUi styles import to #{target_css.relative_path_from(Rails.root)}", :green
      end
    end
  end
end