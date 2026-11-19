module RecurrenceUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecurrenceUi Stimulus controller registration, CSS styles, and initializer"

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

        additions << application_import unless content.include?(application_import)
        additions << recurrence_import unless content.include?(recurrence_import)
        additions << recurrence_registration unless content.include?(recurrence_registration)

        if additions.empty?
          say "RecurrenceUi controller is already registered", :blue
        else
          append_to_file app_js_path, "\n\n#{additions.join("\n")}\n"
          say "Added RecurrenceUi controller registration to application.js", :green
        end
      end

      def register_styles
        say "2. Installing RecurrenceUi CSS styles", :green

        stylesheet_paths = [
          Rails.root.join("app/assets/stylesheets/application.css"),
          Rails.root.join("app/assets/stylesheets/application.scss"),
          Rails.root.join("app/assets/stylesheets/application.sass")
        ]

        target_css = stylesheet_paths.find { |path| File.exist?(path) }

        unless target_css
          say 'Stylesheet not found. Please import "recurrence_ui/application" in your main stylesheet manually.', :yellow
          return
        end

        content = File.read(target_css)
        import_line = '@import "recurrence_ui/application";'

        if content.include?("recurrence_ui/application")
          say "RecurrenceUi styles are already imported in #{target_css.relative_path_from(Rails.root)}", :blue
          return
        end

        if content.include?("*= require_tree .") || content.include?("*= require_self")
          # Для Sprockets-манифестов с директивами *=
          inject_into_file target_css, "\n *= require recurrence_ui/application", after: "*= require_self"
        else
          prepend_to_file target_css, "#{import_line}\n"
        end

        say "Added RecurrenceUi styles import to #{target_css.relative_path_from(Rails.root)}", :green
      end

      def create_initializer
        say "3. Adding RecurrenceUi initializer", :green

        initializer_path = "config/initializers/recurrence_ui.rb"
        if File.exist?(initializer_path)
          say "RecurrenceUi initializer already exists", :blue
          return
        end

        template "recurrence_ui.rb", initializer_path
        say "Created RecurrenceUi initializer at #{initializer_path}", :green
      end
    end
  end
end