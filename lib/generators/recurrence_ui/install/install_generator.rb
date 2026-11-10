module RecurrenceUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecurrenceUi JavaScript and CSS integration into the application"

      def register_js
        app_js_paths = [
          Rails.root.join("app/javascript/application.js"),
          Rails.root.join("app/javascript/packs/application.js")
        ]

        target_js = app_js_paths.find { |path| File.exist?(path) }

        if target_js
          content = File.read(target_js)
          
          if content.include?("recurrence_ui")
            say "RecurrenceUi is already registered in #{target_js.relative_path_from(Rails.root)}", :yellow
          else
            append_to_file target_js, <<~JS

              // Register RecurrenceUi Stimulus controller
              import { registerRecurrenceUiController } from "recurrence_ui"
              registerRecurrenceUiController(application)
            JS
            say "Added RecurrenceUi registration to #{target_js.relative_path_from(Rails.root)}", :green
          end
        else
          say "Could not find application.js. Please register RecurrenceUi manually.", :red
        end
      end

      def register_styles
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        tailwind_css_alt_path = Rails.root.join("app/assets/stylesheets/application.tailwind.css")

        target_css = if File.exist?(tailwind_css_path)
                       tailwind_css_path
                     elsif File.exist?(tailwind_css_alt_path)
                       tailwind_css_alt_path
                     else
                       nil
                     end

        if target_css
          content = File.read(target_css)
          import_line = '@import "recurrence_ui/application.css";'

          unless content.include?(import_line)
            if content.include?('@import "tailwindcss";')
              inject_into_file target_css, "\n#{import_line}", after: '@import "tailwindcss";'
            else
              prepend_to_file target_css, "#{import_line}\n"
            end
            say "Added RecurrenceUi styles import to #{target_css.relative_path_from(Rails.root)}", :green
          else
            say "RecurrenceUi styles import already exists in #{target_css.relative_path_from(Rails.root)}", :blue
          end
        else
          say "Tailwind CSS file not found. Please add `@import \"recurrence_ui/application.css\";` manually.", :yellow
        end
      end
    end
  end
end