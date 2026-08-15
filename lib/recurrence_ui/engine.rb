# recurrence_ui/lib/recurrence_ui/engine.rb
module RecurrenceUi
  class Engine < ::Rails::Engine
    isolate_namespace RecurrenceUi
    # It is only for Tailwind v3
    initializer "recurrence_ui.tailwindcss" do |app|
      if app.config.respond_to?(:tailwindcss)
        app.config.tailwindcss.content_paths << Engine.root.join("app/components/**/*.{erb,haml,html,slim,rb}").to_s
        app.config.tailwindcss.content_paths << Engine.root.join("app/views/**/*.{erb,haml,html,slim,rb}").to_s
      end
    end

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
    
    initializer "recurrence_ui.append_routes" do |app|
      app.routes.append do
        # Добавляем роуты для тестирования переводов  прямо в основное приложение
        if Rails.env.development?
          get '/dev/recurrence_previews', to: 'recurrence_ui/dev/recurrence_previews#index'
        end
      end
    end
    # Автоматически регистрируем файлы переводов гема:
    initializer "recurrence_ui.locales" do |app|
      config.i18n.load_path += Dir[Engine.root.join("config", "locales", "*.{rb,yml}")]
    end
    initializer "recurrence_ui.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
      end
    end
  end
end