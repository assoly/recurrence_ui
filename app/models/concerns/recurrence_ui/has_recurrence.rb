# recurrence_ui/app/models/concerns/recurrence_ui/has_recurrence.rb
module RecurrenceUi
  module HasRecurrence
    extend ActiveSupport::Concern

    included do
      serialize :recurring_rules, type: Hash, coder: YAML # или JSON / JSONB
    end
  def recurring_rules=(value)
    # 1. Если пришла строка (например, JSON от Stimulus), парсим ее
    if value.is_a?(String) && value.present?
      begin
        value = JSON.parse(value)
      rescue JSON::ParserError
        Rails.logger.warn "Failed to parse recurring_rules JSON string."
        value = nil
      end
    end

    # 2. Если значение является непустым хэшем, сохраняем его.
    if value.is_a?(Hash) && value.present?
       # Опционально: можно добавить проверку, что это валидный IceCube хэш
       super(value) 
    else
       super(nil)
    end
  end
  
  # Получение правила IceCube (для генерации событий)
  def rule
    return nil if recurring_rules.blank? || recurring_rules == {}

    # 1. Глубокое клонирование хэша, чтобы не менять исходные данные
    rule_hash = recurring_rules.deep_dup 

    # 2. ✅ ИСПРАВЛЕНИЕ: Конвертируем 0 -> 7 ТОЛЬКО для Monthly day_of_week
    # Используем ключи-строки, так как YAML/JSON парсит ключи в строки
    if rule_hash['rule_type'] == 'IceCube::MonthlyRule' && 
       rule_hash.dig('validations', 'day_of_week').present?
       
       # Проходим по всем N-ым неделям (ключи "1", "2", "-1" и т.д.)
       rule_hash['validations']['day_of_week'].each do |nth, days|
          # Заменяем 0 на 7 в массиве дней недели
          rule_hash['validations']['day_of_week'][nth] = days.map do |day_index|
             # day_index должен быть числом, так как IceCube сохраняет числа
             day_index == 0 ? 7 : day_index 
          end
       end
    end
    
    # IceCube::Rule.from_hash теперь получает скорректированный хэш
    r = IceCube::Rule.from_hash(rule_hash)
    # 2. ДОБАВЛЯЕМ ОГРАНИЧЕНИЕ ПО ДАТЕ
    # Если в модели есть поле repeat_until и оно заполнено
    if respond_to?(:repeat_until) && repeat_until.present?
      # .end_of_day гарантирует, что задача сработает и в последний день тоже
      r = r.until(repeat_until.to_time.end_of_day)
    end
    
    r
    rescue
      nil
  end

  # Генерация расписания IceCube
  def schedule(start_time = nil)
    # start_time должен быть объектом Time или DateTime
    base_time = start_time || self.calendar_datetime&.to_time || Time.current
    s = IceCube::Schedule.new(base_time)
    
    # Если правило существует, добавляем его
    s.add_recurrence_rule(rule) if rule.present?
    
    s
  end

  # Хелпер для вьюхи: показывает текст правила вместе с датой окончания
  def upcoming_occurrences(limit = 5)
    # Метод next_occurrences — это стандартный метод IceCube::Schedule
    # Он принимает количество и время, от которого считать
    # Начинаем поиск с 00:00:00 сегодняшнего дня
    schedule(calendar_datetime).next_occurrences(limit, Time.current.beginning_of_day)
  end
# Проверить нужно ли это или рудимент
  def recurring_text
    return I18n.t("recurrence_ui.once") if recurring_rules.blank?
    
    text = rule.to_s
    # IceCube автоматически добавит "until [Date]" в to_s, если мы вызвали .until(date)
    text
  end
end
end
