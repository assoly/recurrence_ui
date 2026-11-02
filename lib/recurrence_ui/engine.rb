# file: recurrence_ui/lib/recurrence_ui/engine.rb
require "recurrence_ui"

module RecurrenceUi
  class Engine < ::Rails::Engine
    isolate_namespace RecurrenceUi

    # 1. Add importmap support for the gem
    #initializer "recurrence_ui.importmap", before: "importmap" do |app|
    #  if app.config.respond_to?(:importmap)
    #    app.config.importmap.paths << Engine.root.join("config/importmap.rb")
    #  end
    #end

    # 2. Assets (только стили и картинки, если нужны, т.к. JS обслуживает Importmap)
    initializer "recurrence_ui.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w( recurrence_ui/application.css )
      end
    end

    # 3. i18n locales
    initializer "recurrence_ui.locales" do |app|
      config.i18n.load_path += Dir[Engine.root.join("config", "locales", "*.{rb,yml}")]
    end

    # Add components to the global ViewComponent / ActionView search
    config.to_prepare do
      ApplicationController.helper(RecurrenceUi::Engine.helpers)
    end
  end
end