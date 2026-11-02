# config/importmap.rb in the recurrence_ui gem
pin "recurrence_ui", to: "recurrence_ui/index.js"
pin "recurrence_ui/recurrence_ui_controller", to: "recurrence_ui/recurrence_ui_controller.js"

# Явно указываем Importmap, где лежат файлы гема на диске
pin_all_from File.expand_path("../app/javascript/recurrence_ui", __dir__), under: "recurrence_ui"
