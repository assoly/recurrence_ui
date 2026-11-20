# lib/generators/recurrence_ui/install/install_generator.rb
module RecurrenceUi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      APP_JS_PATH = "app/javascript/application.js"
      APP_LAYOUT_PATHS = ["app/views/layouts/application.html.erb"]
      STYLESHEET_ASSET = "recurrence_ui/application".freeze

      desc "Installs RecurrenceUi Stimulus controller registration, CSS styles, and initializer"

      def register_controller
        say "1. Installing RecurrenceUi Stimulus controller registration", :green

        app_js_path = Rails.root.join(APP_JS_PATH)

        unless File.exist?(app_js_path)
          say "Could not find #{APP_JS_PATH}. Please register RecurrenceUi manually.", :red
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
          say "Added RecurrenceUi controller registration to #{APP_JS_PATH}", :green
        end
      end

      def add_stylesheet_link_tag
        say "2. Installing RecurrenceUi stylesheet link into application layout", :green

        APP_LAYOUT_PATHS.each do |lo_path|
          layout_path = Rails.root.join(lo_path)
          unless File.exist?(layout_path)
            say "Could not find #{layout_path.relative_path_from(Rails.root)}. Please add `<%= stylesheet_link_tag \"#{STYLESHEET_ASSET}\", \"data-turbo-track\": \"reload\" %>` manually.", :yellow
            next
          end

          content = File.read(layout_path)

          if content.include?(STYLESHEET_ASSET)
            say "RecurrenceUi stylesheet already included in #{layout_path.relative_path_from(Rails.root)}", :blue
            next
          end

          tag = %(    <%= stylesheet_link_tag "#{STYLESHEET_ASSET}", "data-turbo-track": "reload" %>\n)

          if content.match?(/^\s*<%=\s*stylesheet_link_tag\b.*%>/)
            inject_into_file layout_path, tag, after: /^\s*<%=\s*stylesheet_link_tag\b.*%>\n/
          elsif content.include?("</head>")
            inject_into_file layout_path, tag, before: /\s*<\/head>/
          else
            say "Could not find a suitable place in #{layout_path.relative_path_from(Rails.root)}. Please add:\n#{tag}", :yellow
            next
          end

          say "Added #{STYLESHEET_ASSET} stylesheet to #{layout_path.relative_path_from(Rails.root)}", :green
        end
      end

      def create_initializer
        say "3. Adding RecurrenceUi initializer", :green

        initializer_path = "config/initializers/recurrence_ui.rb"
        if File.exist?(Rails.root.join(initializer_path))
          say "RecurrenceUi initializer already exists", :blue
          return
        end

        template "recurrence_ui.rb", initializer_path
        say "Created RecurrenceUi initializer at #{initializer_path}", :green
      end
    end
  end
end