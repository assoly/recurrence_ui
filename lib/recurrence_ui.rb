require "rails"
require "view_component" 
require "ice_cube" # непосредственно с этим гемом мы работаем, чтобы строить расписания
require "heroicons-rails" # проверить все иконки и положить вх в проект, затем зависимость можно убрать
require "rails-i18n" # нужен для работы с правилами разных языков (например, для японского языка)

require "recurrence_ui/version"
require "recurrence_ui/engine"

module RecurrenceUi
end
