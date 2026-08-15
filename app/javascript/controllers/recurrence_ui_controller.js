// app/javascript/controllers/recurrence_ui_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "selected" ]
  static values = { 
    translations: Object,
    locale: { type: String, default: 'en' },
    timeZone: { type: String, default: 'UTC' }
  }

  static targets = [
    "ruleType", "specificFields", "hiddenField", "displayMode", "editMode", 
    "summaryText", "iceCubeField", "dayButton",
    
    // Интервалы
    "interval",
    
    // Monthly
    "monthlyDays",
    "nthDayBtn",

    // Yearly
    "monthSelector",
    "monthInput",

    // Окончание повторения
    "terminationBlock", "endType", "endDate", "endCount", "endCountInput",
    
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
        
        if (this.hasRuleTypeTarget) {
          this.ruleTypeTarget.value = ruleType
        }
        
        // Переключаем видимость вкладок
        this.toggleFields() 

        // Ищем контейнер активной вкладки
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

          // Синхронизируем кнопки
          this._syncButtonsFromHash(container, ruleHash)
        }

        this._fillTerminationFields(ruleHash)
        this.showDisplayMode()
      } catch (e) {
        console.error("Parsing error:", e)
      }
    } else {
      if (this.hasRuleTypeTarget) this.ruleTypeTarget.value = 'never'
      this.toggleFields()
      this.showEditMode()
    }
    this.updateDebugField()
  }

  saveRule(event) {
    event.preventDefault()
    this.updateHiddenHash()
    this.showDisplayMode()
  }

  editRule(event) {
    event.preventDefault()
    this.ruleSnapshot = this.hiddenFieldTarget.value
    this.showEditMode()
  }

  cancelEdit(event) {
    event.preventDefault()
    this.hiddenFieldTarget.value = this.ruleSnapshot || ""
    this.initializeState() 
    this.showDisplayMode()
  }

  showDisplayMode() {
    if (this.hasDisplayModeTarget) this.displayModeTarget.classList.remove('hidden')
    if (this.hasEditModeTarget) this.editModeTarget.classList.add('hidden')
    this.updateSummary()
  }

  showEditMode() {
    if (this.hasDisplayModeTarget) this.displayModeTarget.classList.add('hidden')
    if (this.hasEditModeTarget) this.editModeTarget.classList.remove('hidden')
  }

  toggleFields() {
    if (!this.hasRuleTypeTarget) return
    const selectedValue = this.ruleTypeTarget.value
    this.specificFieldsTargets.forEach(el => el.classList.toggle('hidden', el.dataset.rule !== selectedValue))
    this.toggleExceptionsBlock()
    this.toggleTerminationBlock() 
    this.updateHiddenHash()
  }

  toggleDay(event) {
    event.preventDefault()
    const btn = event.currentTarget
    btn.dataset.selected = (btn.dataset.selected !== 'true').toString()
    this.updateHiddenHash()
  }

  // Исключения (exdates)
  addExdate(e) {
    e.preventDefault();
    const input = this.exdateInputTarget;
    const dateValue = input.value;
    if (!dateValue || this._getExdatesArray().includes(dateValue)) return;

    const content = this.exdateTemplateTarget.innerHTML
      .replace(/VALUE/g, dateValue)
      .replace(/LABEL/g, this._formatDate(dateValue));

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
    if (!this.hasExdatesContainerTarget) return []
    return Array.from(this.exdatesContainerTarget.querySelectorAll('[data-exdate-value]'))
                .map(el => el.dataset.exdateValue);
  }

  // Окончание повторения (termination)
  toggleTerminationBlock() {
    if (!this.hasTerminationBlockTarget || !this.hasRuleTypeTarget) return
    const ruleType = this.ruleTypeTarget.value
    const isHidden = (ruleType === 'never' || ruleType === '')
    this.terminationBlockTarget.classList.toggle('hidden', isHidden)
  }
  
  toggleEndFields() {
    if (!this.hasEndTypeTarget) return
    const mode = this.endTypeTarget.value
    if (this.hasEndDateTarget) this.endDateTarget.classList.toggle('hidden', mode !== 'until')
    if (this.hasEndCountTarget) this.endCountTarget.classList.toggle('hidden', mode !== 'count')
    this.updateHiddenHash()
  }

  updateHiddenHash() {
    if (this.isInitializing || !this.hasRuleTypeTarget) return

    const ruleType = this.ruleTypeTarget.value
    if (ruleType === 'never') {
      this.hiddenFieldTarget.value = ""
      this.updateSummary()
      return
    }

    const container = this.specificFieldsTargets.find(el => el.dataset.rule === ruleType)
    if (!container) return

    const baseType = ruleType.split('_')[0]
    const iceCubeType = `IceCube::${baseType.charAt(0).toUpperCase()}${baseType.slice(1)}Rule`

    let ruleHash = { 
      rule_type: iceCubeType, 
      interval: parseInt(container.querySelector('[data-item="interval"]')?.value) || 1, 
      validations: {},
      exdates: this._getExdatesArray()
    }

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

    delete ruleHash.until
    delete ruleHash.count

    if (this.hasEndTypeTarget) {
      const endType = this.endTypeTarget.value
      
      if (endType === 'until') {
        if (this.hasEndDateTarget && this.endDateTarget.value) {
          ruleHash.until = this.endDateTarget.value + "T23:59:59Z"
        }
      } 
      else if (endType === 'count') {
        if (this.hasEndCountInputTarget && this.endCountInputTarget.value) {
          ruleHash.count = parseInt(this.endCountInputTarget.value)
        }
      }
    }

    if (Object.keys(ruleHash.validations).length === 0) delete ruleHash.validations
    if (ruleHash.exdates.length === 0) delete ruleHash.exdates

    const json = JSON.stringify(ruleHash, null, 2)
    this.hiddenFieldTarget.value = json
    
    this.updateDebugField()
    this.updateSummary()
  }

  // Генерация текста Саммари
 updateSummary() {
    if (!this.hasSummaryTextTarget || !this.hasHiddenFieldTarget) return;

    let hash = {};
    try {
      hash = JSON.parse(this.hiddenFieldTarget.value || "{}");
    } catch (e) {
      hash = {};
    }

    const type = this._determineRuleType(hash);
    if (type === 'never') {
      this.summaryTextTarget.innerHTML = this.t('one_time');
      return;
    }

    const interval = hash.interval || 1;
    const vals = hash.validations || {};

    // 1. Порядковое числительное для русского (3-й, 3-я)
    const intervalGender = (type === 'weekly') ? 'weekly_interval' : 'male';
    const count_f = this.formatOrdinal(interval, intervalGender);

    let termination = "";
    if (hash.until) {
      termination = this.t('until_label', { date: this._formatDate(hash.until.split('T')[0]) });
    } else if (hash.count) {
      termination = this.t('count_label', { count: hash.count });
    }

    let weekdays = "";
    if (vals.day || vals.day_of_week) {
      const listFormatter = new Intl.ListFormat(this.localeValue, { style: 'long', type: 'conjunction' });
      
      if (type === 'weekly' && vals.day) {
        const names = vals.day.map(i => this.translationsValue.weekdays?.day_names_plural?.[i]);
        weekdays = listFormatter.format(names.filter(Boolean));
      } else if (vals.day_of_week) {
        const parts = Object.keys(vals.day_of_week).map(dayKey => {
          const dayIdx = parseInt(dayKey);
          const gender = this.translationsValue.weekdays?.weekday_genders?.[dayIdx] || 'male';
          
          const nths = vals.day_of_week[dayKey].map(n => {
            const specificName = this.translationsValue.nth_names?.[n.toString()] || 
                                 this.translationsValue.nth_names?.[gender]?.[n.toString()];
            return specificName || this.formatOrdinal(n, gender);
          });
          
          return `${listFormatter.format(nths)} ${this.translationsValue.weekdays?.day_names?.[dayIdx]}`;
        });
        weekdays = parts.join('; ');
      }
    }

    const month = (vals.month_of_year) ? 
      this.translationsValue.in_month_names_yearly?.[vals.month_of_year[0]] : "";

    let days_of_month = "";
    if (vals.day_of_month) {
      const formattedDates = vals.day_of_month.map(d => this.formatOrdinal(d, 'day_of_month'));
      const listFormatter = new Intl.ListFormat(this.localeValue, { style: 'long', type: 'conjunction' });
      const listStr = listFormatter.format(formattedDates);

      days_of_month = this.t('days_of_month_fmt', { list: listStr });
    }

    // Передаем И count (число), И count_f (порядковое)
    const mainText = this.t(`summary.${type}`, {
      count: interval,
      count_f: count_f,
      until: termination,
      weekdays: weekdays,
      month: month,
      days_of_month: days_of_month
    }).replace(/\s+/g, ' ').trim();

    let exceptionsHtml = "";
    if (hash.exdates && hash.exdates.length > 0) {
      const exceptLabel = this.t('labels.exceptions');
      const formattedExdates = hash.exdates
        .sort((a, b) => new Date(a) - new Date(b))
        .map(d => this._formatDate(d))
        .join(', ');

      exceptionsHtml = `<br><span class="text-muted text-sm italic">${exceptLabel}: ${formattedExdates}</span>`;
    }

    this.summaryTextTarget.innerHTML = mainText + exceptionsHtml;
  }

  t(path, params = {}) {
    let result = path.split('.').reduce((o, i) => o ? o[i] : null, this.translationsValue);
    if (!result) return path;

    const count = params.count ?? params.interval;

    if (typeof count === 'number' && typeof result === 'object') {
      if (count === 1 && result['one']) {
        result = result['one'];
      } else {
        const locale = this.localeValue || 'en';
        const pr = new Intl.PluralRules(locale, { type: 'cardinal' });
        const rule = pr.select(count);
        
        result = result[rule] || result['other'] || result['one'] || path;
      }
    }

    if (typeof result !== 'string') return path;

    Object.keys(params).forEach(key => {
      result = result.replace(`%{${key}}`, params[key]);
    });

    return result;
  }

  formatOrdinal(number, gender = 'male') {
    const locale = this.localeValue;
    const ruleType = locale.startsWith('en') ? 'ordinal' : 'cardinal';
    const pr = new Intl.PluralRules(locale, { type: ruleType });
    const rule = pr.select(number);

    const ordinals = this.translationsValue.ordinals || {};
    const genderGroup = ordinals[gender] || ordinals;

    let template = (typeof genderGroup === 'object' && genderGroup !== null) ? (genderGroup[rule] || genderGroup['other']) : null;
    
    if (!template && ordinals['other']) {
      template = ordinals['other'];
    }

    if (typeof template !== 'string') {
      return number.toString();
    }

    return template.replace('%{count}', number);
  }
  
  syncButtonsUI() {
    if (!this.hasSelectedClasses) return
    this.element.querySelectorAll('[data-selected]').forEach(btn => {
      btn.classList.remove(...this.selectedClasses)
    })

    this.element.querySelectorAll('[data-selected="true"]').forEach(btn => {
      btn.classList.add(...this.selectedClasses)
    })
  }

  updateDebugField() {
    if (this.hasIceCubeFieldTarget) this.iceCubeFieldTarget.value = this.hiddenFieldTarget.value
  }

  toggleExceptionsBlock() {
    if (!this.hasExceptionsBlockTarget || !this.hasRuleTypeTarget) return
    const ruleType = this.ruleTypeTarget.value
    const isHidden = (ruleType === 'never' || ruleType === '')
    this.exceptionsBlockTarget.classList.toggle('hidden', isHidden)
  }

  updateHiddenFromDebug() {
    try {
      JSON.parse(this.iceCubeFieldTarget.value)
      this.hiddenFieldTarget.value = this.iceCubeFieldTarget.value
      this.initializeState()
    } catch (e) {}
  }

  _determineRuleType(hash) {
    if (!hash || !hash.rule_type) return 'never'
    
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
    container.querySelectorAll('[data-selected]').forEach(btn => btn.dataset.selected = "false")

    const vals = hash.validations || {}

    if (vals.day) {
      vals.day.forEach(d => {
        const btn = container.querySelector(`[data-value="${d}"]`)
        if (btn) btn.dataset.selected = "true"
      })
    }

    if (vals.day_of_month) {
      vals.day_of_month.forEach(d => {
        const btn = container.querySelector(`[data-day="${d}"]`)
        if (btn) btn.dataset.selected = "true"
      })
    }

    if (vals.day_of_week) {
      Object.keys(vals.day_of_week).forEach(dayNum => {
        vals.day_of_week[dayNum].forEach(nth => {
          const btn = container.querySelector(`[data-day="${dayNum}"][data-nth="${nth}"]`)
          if (btn) btn.dataset.selected = "true"
        })
      })
    }
    
    this.syncButtonsUI()
  }

  _fillTerminationFields(hash) {
    if (!this.hasEndTypeTarget) return

    if (hash.until) {
      this.endTypeTarget.value = 'until'
      if (this.hasEndDateTarget) this.endDateTarget.value = hash.until.split('T')[0]
    } else if (hash.count) {
      this.endTypeTarget.value = 'count'
      if (this.hasEndCountInputTarget) this.endCountInputTarget.value = hash.count
    } else {
      this.endTypeTarget.value = 'never'
    }
    this.toggleEndFields()
  }

  _formatDate(dateString) {
    if (!dateString) return '';

    // Парсим дату в UTC, чтобы избежать сдвигов часовых поясов
    const [year, month, day] = dateString.split('T')[0].split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));

    const y = date.getUTCFullYear();
    const m = date.getUTCMonth() + 1; // 1..12
    const d = date.getUTCDate();

    // Берем формат и массив месяцев прямо из переданного YAML
    const dateConfig = this.translationsValue.date || {};
    const formatPattern = dateConfig.formats?.recurrence_date || "%Y-%m-%d";
    const monthNames = dateConfig.month_names || [];

    // Вытягиваем название месяца (учитывая, что 0-й элемент в массиве nil/null)
    const monthName = monthNames[m] || "";

    // Форматируем строго по шаблону из YAML
    return formatPattern
      .replace(/%Y/g, y)
      .replace(/%-m/g, m)
      .replace(/%m/g, String(m).padStart(2, '0'))
      .replace(/%-d/g, d)
      .replace(/%d/g, String(d).padStart(2, '0'))
      .replace(/%B/g, monthName);
  }
}