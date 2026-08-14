# RecurrenceUi
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "recurrence_ui"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install recurrence_ui
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


### Настройка Tailwind CSS

Наш гем автоматически предоставляет свои HTML-шаблоны для сканирования Tailwind.

#### Если ваше приложение использует Tailwind v3 (`tailwind.config.js`):
Никаких дополнительных действий не требуется! Engine автоматичеcки добавит шаблоны гема в сборку.

*(Если вы подключаете гем через локальный путь `gem "recurrence_ui", path: "..."`, добавьте путь вручную в `tailwind.config.js`):*
```javascript
// config/tailwind.config.js
module.exports = {
  content: [
    './app/**/*.{erb,html,js}',
    // Для локальной разработки гема:
    '../recurrence_ui/app/components/**/*.{erb,html,rb}',
  ]
}
```

#### Если ваше приложение использует Tailwind v4 (`application.css`):
Добавьте директиву `@source` в ваш главный CSS-файл, чтобы указать путь к установленной кассете (gem) или локальной папке:

```css
/* app/assets/stylesheets/application.css */
@import "tailwindcss";

/* Для гема, установленного из Rubygems / Bundler: */
@source "../../gems/recurrence_ui-*";

/* Или если гем подключен локально из соседней папки: */
@source "../../../recurrence_ui/app/components";
```