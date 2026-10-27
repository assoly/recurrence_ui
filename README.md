# Recurrence UI

**Recurrence UI** is a plug-and-play UI component library for Ruby on Rails that makes it easy to create, edit, and display human-readable recurrence rules for recurring events.

Built on top of [ice_cube](https://github.com/ice-cube-ruby/ice_cube), it provides reusable UI components powered by [ViewComponent](https://viewcomponent.org/) and styled with Tailwind CSS.

[![Gem Version](https://badge.fury.io/rb/recurrence_ui.svg)](https://badge.fury.io/rb/recurrence_ui)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- **Form integration:** Ready-to-use components for adding recurrence rule editors to model creation and editing forms.
- **Human-readable descriptions:** Converts `ice_cube` recurrence rules into readable descriptions.
- **Built-in internationalization:** Supports English (`en`), Russian (`ru`), Japanese (`ja`), Belarusian (`be`), and Ukrainian (`uk`).
- **Extensible translations:** Add new locales using standard YAML translation files and configuration.
- **Flexible time zones and week starts:** Configure time zones and the first day of the week. Values can be supplied through URL parameters, session data, user preferences, or application settings, depending on your integration.
- **Customizable styles:** Adjust the color palette using CSS custom properties (design tokens).
- **Light and dark themes:** Customize the appearance to match your application.
- **Flexible model attribute mapping:** Use custom database column names for recurrence rules, time zones, durations, and event start and end times.

## 📦 Requirements

Recurrence UI depends on the following components:

- **Ruby on Rails** >= 7.0
- **[ice_cube](https://github.com/ice-cube-ruby/ice_cube)** ~> 0.16 — recurrence rule management.
- **[ViewComponent](https://viewcomponent.org/)** >= 2.0 — reusable, encapsulated UI components.
- **Tailwind CSS** — styling, integrated through `tailwindcss-rails` or your host application's Tailwind CSS setup.

## 🚀 Installation

Add the gem to your application's `Gemfile`:

```ruby
gem "recurrence_ui"
```

Then install the dependencies:

```bash
bundle install
```

### Importing styles

For Tailwind CSS v4, add the following imports to your application's stylesheet, such as `app/assets/stylesheets/application.tailwind.css`:

```css
@import "tailwindcss";
@import "recurrence_ui/application.css";
```

Make sure the stylesheet is included in your application's asset pipeline and that your Tailwind CSS setup is compatible with the gem's styles.

## ⚙️ Configuration

Create an initializer at `config/initializers/recurrence_ui.rb` to configure the default settings:

```ruby
RecurrenceUi.configure do |config|
  config.locale = :en
  config.time_zone = "UTC"
  config.week_start = 1
end
```

Available settings:

- `locale` — the default interface locale, such as `:en`, `:ru`, `:uk`, `:be`, or `:ja`.
- `time_zone` — the default time zone.
- `week_start` — the first day of the week: `0` for Sunday or `1` for Monday.

The values above are examples. Adjust them to match your application's requirements.

## 🛠 Model Integration

Include `RecurrenceUi::HasRecurrence` in your model and configure the mapping between the gem's attributes and your database columns.

For example:

```ruby
class Event < ApplicationRecord
  include RecurrenceUi::HasRecurrence

  has_recurrence rules:      :recurring_rules,
                 start_time: :start_at,
                 end_time:   :end_at,
                 time_zone:  :time_zone
                 duration:   :duration
end
```

### Using custom attribute names

You can configure different attribute names for different models:

```ruby
class Task < ApplicationRecord
  include RecurrenceUi::HasRecurrence

  has_recurrence rules:      :recurrence_data,
                 start_time: :due_date
end
```

Use the attribute names that match your application's database schema and the attributes supported by your model integration.

## 🎨 View Integration

Render the recurrence editor inside a Rails form using `RecurrenceUi::FormContainerComponent`:

```erb
<%= form_with model: @event do |form| %>
  <%= render RecurrenceUi::FormContainerComponent.new(
        form: form,
        record: @event,
        locale: params[:locale],
        time_zone: params[:time_zone],
        week_start: params[:week_start]
      ) %>

  <%= form.submit "Save" %>
<% end %>
```

The `locale`, `time_zone`, and `week_start` options can be supplied dynamically when needed. If omitted, the component can use the applicable defaults provided by your integration.

## 🌍 Internationalization

Recurrence UI currently supports the following locales:

- English (`en`)
- Russian (`ru`)
- Ukrainian (`uk`)
- Belarusian (`be`)
- Japanese (`ja`)

### Adding a new locale

You can extend the interface with additional translations.

For example, to add German (`de`):

1. Create a translation file named `config/locales/recurrence_ui.de.yml` in your application.
2. Add the required translation keys, including the relevant labels, actions, duration descriptions, and other interface strings.
3. Configure the new locale or pass it dynamically through your application's request parameters.

Make sure the translation file follows the structure expected by the gem's existing locale files.

## 🌓 Themes and Customization

Recurrence UI uses CSS custom properties (design tokens) to control its color palette.

You can override these properties in your application's stylesheet to match your brand or customize the appearance of the interface.

For example:

```css
:root {
  --rui-primary-bg: #2563eb;
}

/* Dark theme */
.dark,
[data-rui-theme="dark"] {
  --rui-bg-main: #1f2937;
  --rui-text-main: #f9fafb;
}
```

Use the CSS variables supported by the gem to customize the interface. The example above illustrates the approach; available tokens and theme selectors depend on the styles provided by your version of Recurrence UI.

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!

To get started:

1. Clone the repository.
2. Install the dependencies:

   ```bash
   bundle install
   ```

3. Run the test suite:

   ```bash
   bundle exec rake test
   ```

4. Create a branch, make your changes, and open a pull request.

Please make sure your changes are covered by tests where appropriate.
## 🧪 Testing

*Note: The test suite is currently under active development. Contributions are very welcome!*

### Planned Test Suite

- [ ] **Models & Concerns (`HasRecurrence`):** Test attribute mapping, JSON parsing, virtual form attributes, and `IceCube::Schedule` generation.
- [ ] **Formatter Service (`RecurrenceFormatterService`):** Validate human-readable summaries, smart date/time deduplication, and month declensions.
- [ ] **Internationalization (I18n):** Automated checks to ensure all locales (`en`, `ru`, `uk`, `be`, `ja`) share a consistent translation key structure.
- [ ] **ViewComponents:** Test proper rendering and Stimulus data-attribute bindings for form components.

## 📄 License

Recurrence UI is available under the [MIT License](https://opensource.org/licenses/MIT).