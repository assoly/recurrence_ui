require "recurrence_ui"

module RecurrenceUi
  class Engine < ::Rails::Engine
    isolate_namespace RecurrenceUi

    # Assets: JavaScript and CSS
    initializer "recurrence_ui.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/javascript")
        app.config.assets.paths << root.join("app/assets/stylesheets")
        #app.config.assets.precompile += %w(recurrence_ui/application.css)
      end
    end

    # Importmap
    initializer "recurrence_ui.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/javascript")
    end

    # I18n locales
    initializer "recurrence_ui.locales" do |app|
      app.config.i18n.load_path += Dir[
        root.join("config", "locales", "*.{rb,yml}")
      ]
    end

    # ViewComponent / ActionView helpers
    config.to_prepare do
      ApplicationController.helper(RecurrenceUi::Engine.helpers)
    end
  end
end