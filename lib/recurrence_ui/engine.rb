# recurrence_ui/lib/recurrence_ui/engine.rb
module RecurrenceUi
  class Engine < ::Rails::Engine
    isolate_namespace RecurrenceUi

    initializer "recurrence_ui.assets" do |app|
      if app.config.respond_to?(:assets)
        # 1. Регистрируем папку app/javascript
        app.config.assets.paths << Engine.root.join("app/javascript")
        app.config.assets.paths << Engine.root.join("app/assets/stylesheets")

        # 2. Автоматически разрешаем Sprockets прекомпилировать JS-контроллеры гема
        app.config.assets.precompile += %w( 
          controllers/recurrence_ui_controller.js 
          recurrence_ui.css
        )
      end
    end

    initializer "recurrence_ui.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
      end
    end
  end
end