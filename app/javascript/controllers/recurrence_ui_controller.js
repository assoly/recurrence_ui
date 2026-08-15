// /app/javascript/controllers/recurrence_ui_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "selected" ]
  static values = { 
    translations: Object,
    locale: { type: String, default: 'en-US' },
    timeZone: { type: String, default: 'UTC' }
  }

  static targets = [
    "ruleType", "specificFields", "hiddenField", "displayMode", "editMode", 
    "summaryText", "iceCubeField", "dayButton",
    
    // Интервалы для разных типов правил (нужны для updateHiddenHash)
    "interval",
    
    // Monthly специфичные (нужны для updateHiddenHash)
    "monthlyDays",   // Контейнеры панелей (числа/дни недели)
    "nthDayBtn", // Кнопки внутри сетки Nth-дней (для yearly_by_weekday)

    // Yearly специфичные
    "monthSelector",
    "monthInput", // Выбор месяца для yearly правил

    // Окончание повторения
    "terminationBlock", "endType", "endDate", "endCount", "endCountInput", // Поля для окончания повторения
    
    // Исключения
    "exceptionsBlock", "exdatesContainer", "exdateInput", "exdateTemplate"
  ]
  ruleSnapshot = null

  connect() {
    this.isInitializing = true
    this.initializeState()
    this.syncButtonsUI()
    this.toggleExceptionsBlock() 
    this.toggleTerminationBlock() 
    this.updateSummary()
    this.isInitializing = false
  }

  // ИНИЦИАЛИЗАЦИЯ
  initializeState() {
    const ruleHashString = this.hiddenFieldTarget.value
    
    if (ruleHashString && ruleHashString.length > 2) { 
      try {
        const ruleHash = JSON.parse(ruleHashString)
        const ruleType = this._determineRuleType(ruleHash)
        
        this.ruleTypeTarget.value = ruleType
        
        // Сначала переключаем видимость вкладок
        this.toggleFields() 

        // Теперь ищем контейнер активной вкладки
        const container = this.specificFieldsTargets.find(el => el.dataset.rule === ruleType)
        
        if (container) {
          // Заполняем интервал
          const intervalInput = container.querySelector('[data-item="interval"]')
          if (intervalInput && ruleHash.interval) {
            intervalInput.value = ruleHash.interval
          }
          
          // Заполняем месяц для годовых правил
          if (ruleType.startsWith('yearly')) {
            const monthInput = container.querySelector('[data-item="month"]')
            if (monthInput && ruleHash.validations?.month_of_year) {
              monthInput.value = ruleHash.validations.month_of_year[0]
            }
          }

          // Синхронизируем кнопки (дни недели, числа месяца)
          this._syncButtonsFromHash(container, ruleHash)
        }

        this._fillTerminationFields(ruleHash)
        this.showDisplayMode()
      } catch (e) {
        console.error("Parsing error:", e)
      }
    } else {
      this.ruleTypeTarget.value = 'never'
      this.toggleFields()
      this.showEditMode()
    }
    this.updateDebugField()
  }

  // Сохранение правила (кнопка Save)
  saveRule(event) {
    event.preventDefault()
    this.updateHiddenHash()
    this.showDisplayMode()
  }

  // Редактирование правила (кнопка Edit) - сохраняем текущее состояние в snapshot перед переключением в режим редактирования 
  editRule(event) {
    event.preventDefault()
    this.ruleSnapshot = this.hiddenFieldTarget.value // Сохраняем состояние
    this.showEditMode()
  }

  // Логика отмены (кнопка Cancel) - возвращаем предыдущее значение из snapshot
  cancelEdit(event) {
    event.preventDefault()
    // Возвращаем данные из снимка
    this.hiddenFieldTarget.value = this.ruleSnapshot || ""
    this.initializeState() 
    this.showDisplayMode()
  }



  //Переключение видимости режимов DISPLAY/EDIT - преключение в режим отображения Саммари
  showDisplayMode() {
    this.displayModeTarget.classList.remove('hidden')
    this.editModeTarget.classList.add('hidden')
    this.updateSummary()
  }
  //Переключение видимости режимов DISPLAY/EDIT - преключение в режим редактирования правил повторения
  showEditMode() {
    this.displayModeTarget.classList.add('hidden')
    this.editModeTarget.classList.remove('hidden')
  }

  // 3. ОБРАБОТЧИКИ СОБЫТИЙ (ACTIONS)
  toggleFields() {
    const selectedValue = this.ruleTypeTarget.value
    this.specificFieldsTargets.forEach(el => el.classList.toggle('hidden', el.dataset.rule !== selectedValue))
    this.toggleExceptionsBlock()
    this.toggleTerminationBlock() 
    this.updateHiddenHash()
  }

  // Универсальный переключатель для ВСЕХ кнопок (Пн, Вт, 1, 2, 3...)
  toggleDay(event) {
    event.preventDefault()
    const btn = event.currentTarget
    btn.dataset.selected = (btn.dataset.selected !== 'true').toString()
    this.updateHiddenHash()
  }

  // Блок для исключительных дат (exdates)
  addExdate(e) {
    e.preventDefault();
    const input = this.exdateInputTarget;
    const dateValue = input.value;
    if (!dateValue || this._getExdatesArray().includes(dateValue)) return;

    // Клонируем темплейт
    const content = this.exdateTemplateTarget.innerHTML
      .replace(/VALUE/g, dateValue)
      .replace(/LABEL/g, this._formatDate(dateValue)); // Твой метод форматирования

    this.exdatesContainerTarget.insertAdjacentHTML('beforeend', content);
    input.value = "";
    this.updateHiddenHash();
  }
  removeExdate(e) {
    e.preventDefault();
    e.target.closest('[data-exdate-value]').remove();
    this.updateHiddenHash();
  }

  _getExdatesArray() {
    return Array.from(this.exdatesContainerTarget.querySelectorAll('[data-exdate-value]'))
                .map(el => el.dataset.exdateValue);
  }
  //Конец блока для исключительных дат

  //Блок окончания повторения (termination)
  toggleTerminationBlock() {
    // 1. Проверяем наличие таргета перед манипуляцией (Принцип защиты)
    if (!this.hasTerminationBlockTarget) return

    const ruleType = this.ruleTypeTarget.value
    
    // 2. Блок должен быть виден только если выбрано какое-то правило повторения
    const isHidden = (ruleType === 'never' || ruleType === '')
    
    this.terminationBlockTarget.classList.toggle('hidden', isHidden)
  }
  
  toggleEndFields() {
    const mode = this.endTypeTarget.value
    this.endDateTarget.classList.toggle('hidden', mode !== 'until')
    this.endCountTarget.classList.toggle('hidden', mode !== 'count')
    this.updateHiddenHash()
  }
  // Конец блока окончания повторения
  // Сбор данных со всех полей и обновление скрытого поля в формате JSON, который понимает IceCube
  updateHiddenHash() {
    if (this.isInitializing) return

    const ruleType = this.ruleTypeTarget.value
    if (ruleType === 'never') {
      this.hiddenFieldTarget.value = ""
      this.updateSummary()
      return
    }

    // 1. Находим активный контейнер (Daily, Weekly и т.д.)
    const container = this.specificFieldsTargets.find(el => el.dataset.rule === ruleType)
    if (!container) return

    const baseType = ruleType.split('_')[0]
    const iceCubeType = `IceCube::${baseType.charAt(0).toUpperCase()}${baseType.slice(1)}Rule`

    // 2. Инициализируем объект правила (СЮДА СРАЗУ ПОПАДАЮТ ИСКЛЮЧЕНИЯ)
    let ruleHash = { 
      rule_type: iceCubeType, 
      interval: parseInt(container.querySelector('[data-item="interval"]')?.value) || 1, 
      validations: {},
      exdates: this._getExdatesArray() // <--- ТВОИ ИСКЛЮЧЕНИЯ СОХРАНЯЮТСЯ ЗДЕСЬ
    }

    // 3. Сбор валидаций (дни недели, числа месяца и т.д.)
    if (ruleType === 'weekly') {
      const days = Array.from(container.querySelectorAll('[data-selected="true"]'))
                        .map(b => parseInt(b.dataset.value))
      if (days.length > 0) ruleHash.validations.day = days
    } 
    else if (ruleType.endsWith('_day_of_month')) {
      const days = Array.from(container.querySelectorAll('[data-selected="true"]'))
                        .map(b => parseInt(b.dataset.day))
      if (days.length > 0) ruleHash.validations.day_of_month = days
    }
    else if (ruleType.endsWith('_by_weekday')) {
      const nthDays = {}
      container.querySelectorAll('[data-selected="true"]').forEach(btn => {
        const day = btn.dataset.day
        const nth = parseInt(btn.dataset.nth)
        if (!nthDays[day]) nthDays[day] = []
        nthDays[day].push(nth)
      })
      if (Object.keys(nthDays).length > 0) ruleHash.validations.day_of_week = nthDays
    }

    if (ruleType.startsWith('yearly')) {
      const month = parseInt(container.querySelector('[data-item="month"]')?.value)
      if (month) ruleHash.validations.month_of_year = [month]
    }

    // 4.Сбор завершения (по дате или по количеству повторений)
    // удаляем старые ключи, чтобы не было конфликта (либо count, либо until)
    delete ruleHash.until
    delete ruleHash.count

    if (this.hasEndTypeTarget) {
      const endType = this.endTypeTarget.value
      
      if (endType === 'until') {
        if (this.hasEndDateTarget && this.endDateTarget.value) {
          // Сохраняем дату завершения
          ruleHash.until = this.endDateTarget.value + "T23:59:59Z" // Добавляем время, чтобы правило действовало до конца дня
        }
      } 
      else if (endType === 'count') {
        if (this.hasEndCountInputTarget && this.endCountInputTarget.value) {
          // Сохраняем количество повторений
          ruleHash.count = parseInt(this.endCountInputTarget.value)
        }
      }
    }

    // 5. Очистка пустых полей
    if (Object.keys(ruleHash.validations).length === 0) delete ruleHash.validations
    if (ruleHash.exdates.length === 0) delete ruleHash.exdates

    // 6. Запись в скрытое поле в виде JSON
    const json = JSON.stringify(ruleHash, null, 2)
    this.hiddenFieldTarget.value = json
    
    this.updateDebugField()
    this.updateSummary()
  }

  

  // Создание человекочитаемого текста из JSON правила повторения для отображения заглушки в режиме Display
  updateSummary() {
    const hash = JSON.parse(this.hiddenFieldTarget.value);
    const type = this.ruleTypeTarget.value;
    const interval = hash.interval || 1;
    const vals = hash.validations || {};

    // 1. Форматируем окончание для интервала
    // Если неделя — используем спец. род 'weekly_interval', иначе 'male'
    const intervalGender = (type === 'weekly') ? 'weekly_interval' : 'male';
    const count_f = this.formatOrdinal(interval, intervalGender);

    // 2. Форматируем окончание (до...)
    // 2. Форматируем окончание (до даты ИЛИ количество раз)
    let termination = "";
    if (hash.until) {
      termination = this.t('until_label', { date: this._formatDate(hash.until.split('T')[0]) });
    } else if (hash.count) {
      termination = this.t('count_label', { count: hash.count });
    }
    // 3. Собираем дни недели
    let weekdays = "";
    if (vals.day || vals.day_of_week) {
      const listFormatter = new Intl.ListFormat(this.localeValue, { style: 'long', type: 'conjunction' });
      
      if (type === 'weekly') {
        const names = vals.day.map(i => this.translationsValue.weekdays.day_names_plural[i]);
        weekdays = listFormatter.format(names);
      } else {
        // Логика с родами для monthly/yearly_by_weekday
        const parts = Object.keys(vals.day_of_week).map(dayKey => {
          const dayIdx = parseInt(dayKey);
          const gender = this.translationsValue.weekdays.weekday_genders[dayIdx];
          
          const nths = vals.day_of_week[dayKey].map(n => {
            // 1. Сначала ищем в специфических именах (1-й, 2-й, посл.)
            const genderNames = this.translationsValue.nth_names?.[gender] || {};
            const specificName = genderNames[n.toString()];
            
            // 2. Если нашли (например, для "-1" вернет "посл."), берем его
            // 3. Если не нашли, вызываем стандартный formatOrdinal
            return specificName || this.formatOrdinal(n, gender);
          });
          
          return `${listFormatter.format(nths)} ${this.translationsValue.weekdays.day_names[dayIdx]}`;
        });
        weekdays = parts.join('; ');
      }
    }

    // 4. Месяц
    const month = (vals.month_of_year) ? 
      this.translationsValue.in_month_names_yearly[vals.month_of_year[0]] : "";

    // 5. Числа месяца
    let days_of_month = "";
    if (vals.day_of_month) {
      // Просто форматируем числа, используя выделенный контекст 'day_of_month'
      const formattedDates = vals.day_of_month.map(d => {
        return this.formatOrdinal(d, 'day_of_month');
      });

      // Автоматически объединяет элементы с учетом грамматики текущей локали
      const listFormatter = new Intl.ListFormat(this.localeValue, { style: 'long', type: 'conjunction' });
      const listStr = listFormatter.format(formattedDates);

      // Оборачиваем получившуюся строку в языковой шаблон
      days_of_month = this.t('days_of_month_fmt', { list: listStr });
    }
    // 6. Исключения (exdates)
    // Собираем основной текст
    const mainText = this.t(`summary.${type}`, {
      count: interval, // <-- Передаём интервал для выбора формы (one / other)
      count_f: count_f,
      until: termination,
      weekdays: weekdays,
      month: month,
      days_of_month: days_of_month
    }).replace(/\s+/g, ' ').trim();

    // Формируем блок исключений (с тегом <br>)
    let exceptionsHtml = "";
    if (hash.exdates && hash.exdates.length > 0) {
      const exceptLabel = this.t('labels.exceptions');
      const formattedExdates = hash.exdates
        .sort((a, b) => new Date(a) - new Date(b))
        .map(d => this._formatDate(d))
        .join(', ');

      // Добавляем перенос строки и оформляем (можно добавить стили)
      exceptionsHtml = `<br><span class="text-muted text-sm italic">${exceptLabel}: ${formattedExdates}</span>`;
    }

    // Используем innerHTML вместо textContent
    this.summaryTextTarget.innerHTML = mainText + exceptionsHtml;
  }
  // Окончание блока для саммари

  // Универсальный хелпер для получения текста с поддержкой плюрализации (count)
  t(path, params = {}) {
    let result = path.split('.').reduce((o, i) => o ? o[i] : null, this.translationsValue);
    if (!result) return path;

    // 1. Проверяем, передан ли параметр количества (count или interval)
    const count = params.count ?? params.interval;

    if (typeof count === 'number' && typeof result === 'object') {
      // Если интервал равен 1 и у нас есть специальный шаблон 'one' — берем его!
      if (count === 1 && result['one']) {
        result = result['one'];
      } else {
        // Иначе определяем категорию через Intl.PluralRules (one, few, many, other)
        const locale = this.localeValue || 'en';
        const pr = new Intl.PluralRules(locale, { type: 'cardinal' });
        const rule = pr.select(count);
        
        result = result[rule] || result['other'] || result['one'] || path;
      }
    }

    if (typeof result !== 'string') return path;

    // 2. Подставляем переменные (%{count_f}, %{until} и т.д.)
    Object.keys(params).forEach(key => {
      result = result.replace(`%{${key}}`, params[key]);
    });

    return result;
  }
  getSummaryHeader(type, interval) {
    const baseType = type.split('_')[0]; // daily, weekly, monthly, yearly
    
    // 1. Получаем категорию (one, two, few, other)
    const locale = this.localeValue || 'ru';
    const pr = new Intl.PluralRules(locale, { 
      type: baseType === 'weekly' ? 'cardinal' : 'ordinal' // Для англ. важны порядковые
    });
    const rule = pr.select(interval);

    // 2. Достаем префикс ("Каждый" / "Every")
    const every = this.translationsValue[baseType].every;

    // 3. Достаем форму числа ("5-й день" / "5th day")
    const countGroup = this.translationsValue[baseType].count;
    const countString = countGroup[rule] || countGroup['other'];

    // 4. Собираем вместе
    const finalCount = countString.replace('%{count}', interval);
    
    return `${every} ${finalCount}`;
  }
  formatOrdinal(number, gender = 'male') {
    const locale = this.localeValue;
    // Используем 'cardinal' для интервалов и дней в русском/японском, 
    // 'ordinal' логика берется из правил плюрализации
    const ruleType = locale.startsWith('en') ? 'ordinal' : 'cardinal';
    const pr = new Intl.PluralRules(locale, { type: ruleType });
    const rule = pr.select(number);

    // Безопасно достаем группу: сначала с учетом рода, затем общую
    const ordinals = this.translationsValue.ordinals || {};
    const genderGroup = ordinals[gender] || ordinals;

    // Если genderGroup все еще объект, но не содержит нужного ключа 'rule'
    let template = (typeof genderGroup === 'object' && genderGroup !== null) ? (genderGroup[rule] || genderGroup['other']) : null;
    
    // Фолбек на случай, если структура в YAML плоская или глубокая
    if (!template && ordinals['other']) {
      template = ordinals['other'];
    }

    if (typeof template !== 'string') {
      return number.toString();
    }

    return template.replace('%{count}', number);
  }
  
  syncButtonsUI() {
    // 1. Сначала убираем класс со всех кнопок (чтобы сбросить старое состояние)
    this.element.querySelectorAll('[data-selected]').forEach(btn => {
      btn.classList.remove(...this.selectedClasses) // Используем spread, если классов несколько
    })

    // 2. Добавляем класс только выбранным
    this.element.querySelectorAll('[data-selected="true"]').forEach(btn => {
      btn.classList.add(...this.selectedClasses)
    })
  }

  updateDebugField() {
    if (this.hasIceCubeFieldTarget) this.iceCubeFieldTarget.value = this.hiddenFieldTarget.value
  }

  toggleExceptionsBlock() {
    // 1. Проверяем наличие таргета перед манипуляцией (Принцип защиты)
    if (!this.hasExceptionsBlockTarget) return

    const ruleType = this.ruleTypeTarget.value
    
    // 2. Блок должен быть виден только если выбрано какое-то правило повторения
    const isHidden = (ruleType === 'never' || ruleType === '')
    
    this.exceptionsBlockTarget.classList.toggle('hidden', isHidden)
  }

  updateHiddenFromDebug() {
    try {
      JSON.parse(this.iceCubeFieldTarget.value)
      this.hiddenFieldTarget.value = this.iceCubeFieldTarget.value
      this.initializeState() // Перерисовываем UI под новый JSON
    } catch (e) {}
  }
  // Вспомогательный метод для определения типа вкладки по хэшу
  _determineRuleType(hash) {
    if (!hash.rule_type) return 'never'
    
    const base = hash.rule_type.replace('IceCube::', '').replace('Rule', '').toLowerCase()
    
    if (base === 'monthly') {
      return hash.validations?.day_of_week ? 'monthly_by_weekday' : 'monthly_by_day_of_month'
    }
    if (base === 'yearly') {
      return hash.validations?.day_of_week ? 'yearly_by_weekday' : 'yearly_by_day_of_month'
    }
    return base
  }
  _syncButtonsFromHash(container, hash) {
    // Сбрасываем все кнопки в этом контейнере
    container.querySelectorAll('[data-selected]').forEach(btn => btn.dataset.selected = "false")

    const vals = hash.validations || {}

    // Дни недели (weekly или nth-дни)
    if (vals.day) { // IceCube weekly
      vals.day.forEach(d => {
        const btn = container.querySelector(`[data-value="${d}"]`)
        if (btn) btn.dataset.selected = "true"
      })
    }

    // Числа месяца
    if (vals.day_of_month) {
      vals.day_of_month.forEach(d => {
        const btn = container.querySelector(`[data-day="${d}"]`)
        if (btn) btn.dataset.selected = "true"
      })
    }

    // Nth дни (day_of_week как объект)
    if (vals.day_of_week) {
      Object.keys(vals.day_of_week).forEach(dayNum => {
        vals.day_of_week[dayNum].forEach(nth => {
          const btn = container.querySelector(`[data-day="${dayNum}"][data-nth="${nth}"]`)
          if (btn) btn.dataset.selected = "true"
        })
      })
    }
    
    this.syncButtonsUI() // Применяем визуальные классы (bg-blue-600 и т.д.)
  }
  _fillTerminationFields(hash) {
    if (!this.hasEndTypeTarget) return

    if (hash.until) {
      this.endTypeTarget.value = 'until'
      this.endDateTarget.value = hash.until.split('T')[0]
    } else if (hash.count) {
      this.endTypeTarget.value = 'count'
      this.endCountInputTarget.value = hash.count
    } else {
      this.endTypeTarget.value = 'never'
    }
    this.toggleEndFields() // Обновляем видимость инпутов
  }
  _formatDate(dateStr) {
    // Разбиваем "2026-09-01" или "2026-09-01T23:59:59Z"
    const cleanDateStr = dateStr.split('T')[0]; 
    const [year, month, day] = cleanDateStr.split('-').map(Number);

    if (!year || !month || !day) return dateStr;

    // Создаем чистый UTC-объект даты (1 сентября 2026 00:00 UTC)
    const date = new Date(Date.UTC(year, month - 1, day));

    const locale = this.localeValue || 'en-US';

    try {
      return new Intl.DateTimeFormat(locale, {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        timeZone: 'UTC' // Календарные даты бессмысленно сдвигать часовым поясом
      }).format(date);
    } catch (e) {
      console.error("Format error:", e);
      return dateStr;
    }
  }


}