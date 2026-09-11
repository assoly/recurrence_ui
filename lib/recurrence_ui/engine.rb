# recurrence_ui/lib/recurrence_ui/engine.rb
require "recurrence_ui"

module RecurrenceUi
  class Engine < ::Rails::Engine
    isolate_namespace RecurrenceUi

    # 1. Tailwind CSS v3 paths
    initializer "recurrence_ui.tailwindcss" do |app|
      if app.config.respond_to?(:tailwindcss)
        app.config.tailwindcss.content_paths << Engine.root.join("app/components/**/*.{erb,haml,html,slim,rb}").to_s
        app.config.tailwindcss.content_paths << Engine.root.join("app/views/**/*.{erb,haml,html,slim,rb}").to_s
      end
    end

    # 2. Add importmap support for the gem
    initializer "recurrence_ui.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
      end
    end

    # 3. Assets and precompilation of ONLY the necessary files
    initializer "recurrence_ui.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << Engine.root.join("app/javascript")
        app.config.assets.paths << Engine.root.join("app/assets/stylesheets")
        app.config.assets.precompile += %w( recurrence_ui/application.css )

        # Add files for precompilation
        app.config.assets.precompile += %w(
          recurrence_ui/index.js
          recurrence_ui/recurrence_ui_controller.js
          recurrence_ui.css
        )
      end
    end

    # 4. i18n locales
    initializer "recurrence_ui.locales" do |app|
      config.i18n.load_path += Dir[Engine.root.join("config", "locales", "*.{rb,yml}")]
    end

    # 5. Routes for debugging in development
    initializer "recurrence_ui.append_routes" do |app|
      app.routes.append do
        if Rails.env.development?
          get '/dev/recurrence_previews', to: 'recurrence_ui/dev/recurrence_previews#index'
        end
      end
    end
    # Add components to the global ViewComponent / ActionView search
    config.to_prepare do
      ApplicationController.helper(RecurrenceUi::Engine.helpers)
    end
  end
end