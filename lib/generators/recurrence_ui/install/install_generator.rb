module RecurrenceUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecurrenceUi importmap, JS controller registration, and Tailwind CSS styles"

      def add_importmap_pin
        importmap_file = "config/importmap.rb"
        if File.exist?(importmap_file)
          pin_code = "\npin \"recurrence_ui\", to: \"recurrence_ui/index.js\"\n"
          if File.read(importmap_file).include?("recurrence_ui")
            say "RecurrenceUi pin already exists in #{importmap_file}", :blue
          else
            append_to_file importmap_file, pin_code
            say "Added recurrence_ui pin to #{importmap_file}", :green
          end
        else
          say "Could not find #{importmap_file}. Importmap configuration skipped.", :yellow
        end
      end

      def register_controller
        app_js_paths = [
          Rails.root.join("app/javascript/application.js"),
          Rails.root.join("app/javascript/packs/application.js")
        ]

        target_js = app_js_paths.find { |path| File.exist?(path) }

        if target_js
          content = File.read(target_js)
          
          if content.include?("recurrence_ui")
            say "RecurrenceUi is already registered in #{target_js.relative_path_from(Rails.root)}", :blue
          else
            append_to_file target_js, <<~JS

              // Register RecurrenceUi Stimulus controller
              import { registerRecurrenceUiController } from "recurrence_ui"
              if (typeof window.Stimulus !== "undefined") {
                registerRecurrenceUiController(window.Stimulus)
              }
            JS
            say "Added RecurrenceUi registration to #{target_js.relative_path_from(Rails.root)}", :green
          end
        else
          say "Could not find application.js. Please register RecurrenceUi manually.", :red
        end
      end

      def register_styles
        tailwind_css_paths = [
          Rails.root.join("app/assets/tailwind/application.css"),
          Rails.root.join("app/assets/stylesheets/application.tailwind.css"),
          Rails.root.join("app/assets/stylesheets/application.css")
        ]

        target_css = tailwind_css_paths.find { |path| File.exist?(path) }

        if target_css
          content = File.read(target_css)
          import_line = '@import "recurrence_ui/application.css";'

          if content.include?(import_line)
            say "RecurrenceUi styles import already exists in #{target_css.relative_path_from(Rails.root)}", :blue
          else
            if content.include?('@import "tailwindcss";')
              inject_into_file target_css, "\n#{import_line}", after: '@import "tailwindcss";'
            else
              prepend_to_file target_css, "#{import_line}\n"
            end
            say "Added RecurrenceUi styles import to #{target_css.relative_path_from(Rails.root)}", :green
          end
        else
          say "Tailwind CSS file not found. Please add `@import \"recurrence_ui/application.css\";` manually.", :yellow
        end
      end
    end
  end
end