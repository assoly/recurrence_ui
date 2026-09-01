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

    # 2. Подключаем importmap гема
    initializer "recurrence_ui.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
      end
    end

    # 3. Ассеты и прекомпиляция ТОЛЬКО нужных файлов
    initializer "recurrence_ui.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << Engine.root.join("app/javascript")
        app.config.assets.paths << Engine.root.join("app/assets/stylesheets")

        # Явно указываем только целевые файлы гема для прекомпиляции
        app.config.assets.precompile += %w(
          recurrence_ui/index.js
          recurrence_ui/recurrence_ui_controller.js
          recurrence_ui.css
        )
      end
    end

    # 4. Локали i18n
    initializer "recurrence_ui.locales" do |app|
      config.i18n.load_path += Dir[Engine.root.join("config", "locales", "*.{rb,yml}")]
    end

    # 5. Роуты для отладки в development
    initializer "recurrence_ui.append_routes" do |app|
      app.routes.append do
        if Rails.env.development?
          get '/dev/recurrence_previews', to: 'recurrence_ui/dev/recurrence_previews#index'
        end
      end
    end
  end
end