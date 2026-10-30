module RecurrenceUi
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    desc "Интегрирует стили RecurrenceUi в файл Tailwind CSS хост-приложения"

    def add_styles_to_tailwind
      # Ищем главный файл Tailwind v4 в приложении пользователя
      tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
      tailwind_css_alt_path = Rails.root.join("app/assets/stylesheets/application.tailwind.css")

      target_file = if File.exist?(tailwind_css_path)
                      tailwind_css_path
                    elsif File.exist?(tailwind_css_alt_path)
                      tailwind_css_alt_path
                    else
                      nil
                    end

      if target_file
        content = File.read(target_file)
        import_line = '@import "recurrence_ui/application.css";'

        unless content.include?(import_line)
          # Добавляем импорт сразу после @import "tailwindcss"; или в самое начало
          if content.include?('@import "tailwindcss";')
            inject_into_file target_file, "\n#{import_line}", after: '@import "tailwindcss";'
          else
            prepend_to_file target_file, "#{import_line}\n"
          end
          say "Добавлен импорт стилей RecurrenceUi в #{target_file}", :green
        else
          say "Импорт стилей RecurrenceUi уже присутствует в #{target_file}", :blue
        end
      else
        say "Не найден главный CSS-файл Tailwind. Добавьте вручную: @import \"recurrence_ui/application.css\";", :yellow
      end
    end
  end
end
