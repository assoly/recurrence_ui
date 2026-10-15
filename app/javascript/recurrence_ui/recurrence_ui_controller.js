import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "selected" ]
  static values = {
    locale: String,
    timeZone: String,
    weekStart: Number,
    translations: Object
  }

  static targets = [
    "hiddenField", "displayMode", "editMode", "summaryText",
    "rulesContainer", "ruleCardTemplate", "ruleCard",
    "exceptionsBlock", "exdatesContainer", "exdateInput", "addExdateBtn", "exdateTemplate",
    "rdatesBlock", "rdatesContainer", "rdateInput", "addRdateBtn", "rdateTemplate", 
    
    "iceCubeField",
    "visualEditor", // Блок с карточками и кнопками (Level 2)
    "codeEditor",   // Блок с textarea для JSON (Level 2 alt)
    "cardHeader",   // Текстовая заголовок-шапка карточки (для аккордеона Level 3)
    "cardBody",     // Раскрывающийся блок с полями карточки (Level 3)
    "startDate", 
    "startTime", 
    "endDate", 
    "endTime", 
    "modeDuration", 
    "modeEnd", 
    "daysField", 
    "hoursField", 
    "minutesField"
  ]

  ruleSnapshot = null

  connect() {
    this.isInitializing = true
    this.initializeState()
    this.updateDebugField()
    this.initializeDurationMode()
    this.isInitializing = false
  }

// ==========================================
  // INITIALIZATION & STATE MANAGEMENT
  // ==========================================

  initializeState() {
    const jsonString = this.hasHiddenFieldTarget ? this.hiddenFieldTarget.value : null

    // Clear rules container if target exists
    if (this.hasRulesContainerTarget) {
      this.rulesContainerTarget.innerHTML = ""
    }

    // Process rules, exdates, and rdates if JSON string is present
    if (jsonString && jsonString.length > 2) {
      try {
        const schedule = JSON.parse(jsonString)
        const rules = schedule.rrules || (schedule.rule_type ? [schedule] : [])

        if (rules.length > 0) {
          rules.forEach(ruleHash => this._createRuleCardFromHash(ruleHash))
        } else if (this.hasRuleCardTemplateTarget) {
          this.addRule()
        }

        if (this.hasExdatesContainerTarget && this.hasExdateTemplateTarget) {
          this._fillDatesSection(this.exdatesContainerTarget, this.exdateTemplateTarget, schedule.exdates)
        }

        if (this.hasRdatesContainerTarget && this.hasRdateTemplateTarget) {
          this._fillDatesSection(this.rdatesContainerTarget, this.rdateTemplateTarget, schedule.rdates)
        }
      } catch (e) {
        console.error("[RecurrenceUi] JSON Parsing error:", e)
        if (this.hasRuleCardTemplateTarget) this.addRule()
      }
    } else if (this.hasRuleCardTemplateTarget) {
      this.addRule()
    }

    this.toggleExceptionsBlock()
    this.toggleRdatesBlock()
    this.syncButtonsUI()

    // Update the summary text only if there is a target to display it in
    if (this.hasSummaryTextTarget) {
      this.updateSummary()
    }
  }
  // Установка начального состояния полей на основе выбранной радиокнопки
  initializeDurationMode() {
    if (this.hasModeEndTarget) {
      const isEndMode = this.modeEndTarget.checked
      
      if (this.hasEndDateTarget) this.endDateTarget.disabled = !isEndMode
      if (this.hasEndTimeFieldTarget) this.endTimeFieldTarget.disabled = !isEndMode
      if (this.hasDaysFieldTarget) this.daysFieldTarget.disabled = isEndMode
      if (this.hasHoursFieldTarget) this.hoursFieldTarget.disabled = isEndMode
      if (this.hasMinutesFieldTarget) this.minutesFieldTarget.disabled = isEndMode
    }
  }
  // =========================================
  //Переключение длительности и окончания одного события
  // =========================================

  // Переключение между режимом "Длительность" и "Точное окончание"
  toggleDurationEndMode(event) {
    const isEndMode = this.hasModeEndTarget && this.modeEndTarget.checked

    // 1. Блокируем/разблокируем поля длительности
    if (this.hasDaysFieldTarget) this.daysFieldTarget.disabled = isEndMode
    if (this.hasHoursFieldTarget) this.hoursFieldTarget.disabled = isEndMode
    if (this.hasMinutesFieldTarget) this.minutesFieldTarget.disabled = isEndMode

    // 2. Блокируем/разблокируем поля точного окончания (дата и время)
    if (this.hasEndDateTarget) this.endDateTarget.disabled = !isEndMode
    if (this.hasEndTimeFieldTarget) this.endTimeFieldTarget.disabled = !isEndMode

    // 3. Если выбрали режим окончания — автоматически подставляем дату начала в дату окончания, если она пустая
    if (isEndMode && this.hasStartDateTarget && this.hasEndDateFieldTarget) {
      if (!this.endDateFieldTarget.value && this.startDateTarget.value) {
        this.endDateFieldTarget.value = this.startDateTarget.value
      }
    }
  }

  // Переключение U1 -> U2 (Раскрытие общего модуля)
  // Toggle Main Panel Accordion Mode
  toggleMainAccordion() {
    if (!this.hasEditModeTarget) return
    const isHidden = this.editModeTarget.classList.contains('hidden')
    
    if (isHidden) {
      this.editModeTarget.classList.remove('hidden')
    } else {
      this.editModeTarget.classList.add('hidden')
      this.updateSummary() // Recalculate summary text on close
    }
  }

  // Toggle Rule Item Accordion Mode
  toggleCardAccordion(event) {
    if (event) event.preventDefault()

    // Ignore accordion toggle if delete button was clicked directly
    if (event.target.closest('.rui-btn-remove-card')) return

    const card = event.currentTarget.closest(`[data-${this.identifier}-target="ruleCard"]`)
    if (!card) return

    const body = card.querySelector(`[data-${this.identifier}-target="cardBody"]`)
    if (body) {
      const isHidden = body.classList.contains('hidden')
      
      if (isHidden) {
        body.classList.remove('hidden')
        card.classList.add('is-open') // Add active state class
      } else {
        body.classList.add('hidden')
        card.classList.remove('is-open') // Remove active state class
        this.updateCardSummary(card) // Update rule text on collapse
      }
    }
  }
    // 1. Открытие/закрытие панели кода
  toggleCodeEditor(event) {
    if (event) event.preventDefault()

    const isCodeHidden = this.codeEditorTarget.classList.contains('hidden')

    if (isCodeHidden) {
      // Считываем текущий JSON из скрытого поля формы
      const currentJson = this.hiddenFieldTarget.value || "{}"
      
      try {
        // Форматируем JSON с отступами в 2 пробела для красивого отображения в textarea
        const parsed = JSON.parse(currentJson)
        this.iceCubeFieldTarget.value = JSON.stringify(parsed, null, 2)
      } catch (e) {
        // Если там был невалидный JSON, выводим как есть
        this.iceCubeFieldTarget.value = currentJson
      }

      // Переключаем видимость блоков
      this.visualEditorTarget.classList.add('hidden')
      this.codeEditorTarget.classList.remove('hidden')
    } else {
      // Возврат назад без сохранения
      this.codeEditorTarget.classList.add('hidden')
      this.visualEditorTarget.classList.remove('hidden')
    }
  }

  // 2. Применение кода по кнопке "ОК"
  applyCodeChanges(event) {
    if (event) event.preventDefault()

    const rawJson = this.iceCubeFieldTarget.value.trim()

    try {
      // Валидируем JSON перед сохранением
      if (rawJson.length > 0) {
        JSON.parse(rawJson)
      }

      // Сохраняем в основное скрытое поле
      this.hiddenFieldTarget.value = rawJson.length > 0 ? rawJson : "{}"

      // Переинициализируем visual UI (карточки правил, теги дат) под новый JSON
      this.initializeState()

      // Переключаем обратно в визуальный режим
      this.codeEditorTarget.classList.add('hidden')
      this.visualEditorTarget.classList.remove('hidden')

    } catch (e) {
      alert(this.t('errors.invalid_json', { default: 'Ошибка в синтаксисе JSON' }))
    }
  }




  // ==========================================
  // CARD ACTIONS (ADD / REMOVE / TOGGLE)
  // ==========================================

  addRule(event) {
    if (event) event.preventDefault()

    const content = this.ruleCardTemplateTarget.innerHTML
    this.rulesContainerTarget.insertAdjacentHTML('beforeend', content)

    const newCard = this.rulesContainerTarget.lastElementChild
    const body = newCard.querySelector(`[data-${this.identifier}-target="cardBody"]`)
    
    // Раскрываем тело новой карточки
    if (body) body.classList.remove('hidden')

    // Запускаем первичную синхронизацию полей новой карточки
    const select = newCard.querySelector('[data-item="ruleType"]')
    if (select) {
      this.toggleCardFields({ currentTarget: select })
    }

    this.toggleExceptionsBlock()
    this.toggleRdatesBlock()

    this.updateCardSummary(newCard)
    this.updateHiddenHash()
  }




  removeRule(e) {
    e.preventDefault()
    const card = e.target.closest(`[data-${this.identifier}-target="ruleCard"]`)
    if (card) {
      card.remove()
      this.toggleExceptionsBlock()
      this.toggleRdatesBlock()
      this.updateHiddenHash()
    }
  }

  toggleCardFields(e) {
    const select = e.currentTarget
    const card = select.closest(`[data-${this.identifier}-target="ruleCard"]`) || select.closest('[data-item="ruleCard"]')
    if (!card) return

    const selectedValue = select.value
    const specificFields = card.querySelectorAll('[data-item="specificFields"]')
    
    specificFields.forEach(el => {
      const isCurrent = el.dataset.rule === selectedValue
      el.classList.toggle('hidden', !isCurrent)

      // Если выбрали тип с полем (например, daily) и интервал не задан, выставляем 1 по умолчанию
      if (isCurrent) {
        const intervalInput = el.querySelector('[data-item="interval"]')
        if (intervalInput && (!intervalInput.value || parseInt(intervalInput.value) < 1)) {
          intervalInput.value = 1
        }
      }
    })

    this.updateHiddenHash()
    this.updateCardSummary(card)
  }

  toggleDay(event) {
    event.preventDefault()
    const btn = event.currentTarget
    btn.dataset.selected = (btn.dataset.selected !== 'true').toString()
    this.syncButtonsUI()
    this.updateHiddenHash()

    const card = btn.closest(`[data-${this.identifier}-target="ruleCard"]`)
    if (card) this.updateCardSummary(card)

  }

  toggleEndFields(event) {
    const select = event.currentTarget
    const card = select.closest(`[data-${this.identifier}-target="ruleCard"]`)
    if (!card) return

    const mode = select.value
    const endDate = card.querySelector('[data-item="endDateInput"]')
    const endCount = card.querySelector('[data-item="endCount"]')

    if (endDate) endDate.classList.toggle('hidden', mode !== 'until')
    if (endCount) {
      endCount.classList.toggle('hidden', mode !== 'count')
      if (mode === 'count') endCount.classList.add('flex')
    }

    this.updateHiddenHash()
    this.updateCardSummary(card)
  }
  onCardInputChanged(event) {
    const card = event.currentTarget.closest(`[data-${this.identifier}-target="ruleCard"]`)
    this.updateHiddenHash()
    if (card) this.updateCardSummary(card)
  }
  // ==========================================
  // MODE SWITCHING & ACTIONS
  // ==========================================

  saveRule(event) {
    if (event) event.preventDefault()
    this.updateHiddenHash()
    this.showDisplayMode()
  }

  editRule(event) {
    if (event) event.preventDefault()
    this.ruleSnapshot = this.hiddenFieldTarget.value
    this.showEditMode()
  }

  cancelEdit(event) {
    if (event) event.preventDefault()
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

  // ==========================================
  // EXCEPTIONS (EXDATES) & ADDITIONS (RDATES)
  // ==========================================


  // 1. Активация/деактивация кнопки "+" при вводе даты
  onDateInputChange(event) {
    const input = event.target
    const value = input.value.trim()
    
    if (input === this.exdateInputTarget && this.hasAddExdateBtnTarget) {
      this.addExdateBtnTarget.disabled = !value
    } else if (input === this.rdateInputTarget && this.hasAddRdateBtnTarget) {
      this.addRdateBtnTarget.disabled = !value
    }
  }

  // 2. Универсальный метод вставки из <template>
  _addDateFromTemplate(inputTarget, containerTarget, templateTarget) {
    if (!inputTarget || !containerTarget || !templateTarget) return

    const dateValue = inputTarget.value.trim()
    if (!dateValue) return

    // Проверка на дубликаты
    const existingDates = Array.from(containerTarget.children).map(
      el => el.dataset.exdateValue || el.dataset.rdateValue || el.dataset.date
    )
    if (existingDates.includes(dateValue)) return

    // Подставляем данные в template
    const html = templateTarget.innerHTML
      .replace(/VALUE/g, dateValue)
      .replace(/LABEL/g, this._formatDate(dateValue))

    containerTarget.insertAdjacentHTML('beforeend', html)
    inputTarget.value = ''
    this.updateHiddenHash()
  }

  // 3. Добавление исключения (Exdate)
  addExdate(event) {
    if (event) event.preventDefault()
    this._addDateFromTemplate(this.exdateInputTarget, this.exdatesContainerTarget, this.exdateTemplateTarget)
    if (this.hasAddExdateBtnTarget) this.addExdateBtnTarget.disabled = true
  }

  // 4. Добавление дополнительной даты (Rdate)
  addRdate(event) {
    if (event) event.preventDefault()
    this._addDateFromTemplate(this.rdateInputTarget, this.rdatesContainerTarget, this.rdateTemplateTarget)
    if (this.hasAddRdateBtnTarget) this.addRdateBtnTarget.disabled = true
  }

  // 5. Заполнение секции при первичной загрузке из JSON
  _fillDatesSection(container, template, datesArray) {
    if (!container || !template || !datesArray) return
    container.innerHTML = ""
    
    datesArray.forEach(dateValue => {
      const html = template.innerHTML
        .replace(/VALUE/g, dateValue)
        .replace(/LABEL/g, this._formatDate(dateValue))
      container.insertAdjacentHTML('beforeend', html)
    })
  }


  removeExdate(e) {
    e.preventDefault()
    const badge = e.currentTarget.closest('[data-exdate-value]')
    console.log("Removing exdate badge:", badge)
    if (badge) {
      badge.remove()
      this.updateHiddenHash()
    }
  }

  removeRdate(e) {
    e.preventDefault()
    const badge = e.currentTarget.closest('[data-rdate-value]')
    console.log("Removing rdate badge:", badge)
    if (badge) {
      badge.remove()
      this.updateHiddenHash()
    }
  }

  toggleExceptionsBlock() {
    if (!this.hasExceptionsBlockTarget) return
    // Всегда показываем блок исключений в режиме редактирования U2
    this.exceptionsBlockTarget.classList.remove('hidden')
  }

  toggleRdatesBlock() {
    if (!this.hasRdatesBlockTarget) return
    // Всегда показываем блок доп. дат в режиме редактирования U2
    this.rdatesBlockTarget.classList.remove('hidden')
  }

  // ==========================================
  // HASH BUILDER & SUMMARY GENERATION
  // ==========================================

  updateHiddenHash() {
    if (this.isInitializing) return

    // 1. Фильтруем и собираем только валидные rrules (игнорируем тип 'never' или сбойные правила)
    const rrules = this.ruleCardTargets
      .map(card => this._buildSingleRuleHash(card))
      .filter(Boolean)

    // 2. Извлекаем списки дат
    const exdates = this._getDatesArray(this.exdatesContainerTarget, 'exdateValue')
    const rdates = this._getDatesArray(this.rdatesContainerTarget, 'rdateValue')

    // 3. Формируем итоговый объект расписания
    const schedule = {}

    // Записываем rrules только если они есть
    if (rrules.length > 0) {
      schedule.rrules = rrules
    }

    // Записываем exdates только если они есть
    if (exdates.length > 0) {
      schedule.exdates = exdates
    }

    // Записываем rdates только если они есть
    if (rdates.length > 0) {
      schedule.rdates = rdates
    }

    // 4. Записываем в hidden_field чистый JSON (если всё пусто — сохранится "{}" вместо пустых структур)
    this.hiddenFieldTarget.value = JSON.stringify(schedule)

    // 5. Обновляем текстовую сводку и отладчик
    this.updateSummary()
    this.updateDebugField()
  }


  updateCardSummary(card) {
    if (!card) return
    const summaryEl = card.querySelector('[data-item="cardSummary"]')
    if (!summaryEl) return
    // Create a summary text for the card based on its current state
    const ruleHash = this._buildSingleRuleHash(card)
    
    if (!ruleHash) {
      summaryEl.textContent = this.t('labels.new_rule', { default: 'Новое правило' })
      return
    }
    // Generate a human-readable summary for the rule with _buildRuleSummaryText
    const text = this._buildRuleSummaryText(ruleHash)
    summaryEl.textContent = text || this.t('labels.new_rule', { default: 'Новое правило' })
  }
  updateSummary() {
    if (!this.hasSummaryTextTarget || !this.hasHiddenFieldTarget) return

    let schedule = {}
    try {
      schedule = JSON.parse(this.hiddenFieldTarget.value || "{}")
    } catch (e) {
      schedule = {}
    }

    const rrules = schedule.rrules || []
    let mainText = this.t('one_time')
    
    if (rrules.length > 0) {
          // Build human-readable summary for each rule

      const ruleTexts = rrules.map(ruleHash => this._buildRuleSummaryText(ruleHash))
      mainText = ruleTexts.join('; ')
    }


    let exceptionsHtml = ""
    if (schedule.exdates && schedule.exdates.length > 0) {
      const exceptLabel = this.t('labels.exceptions')
      const formattedExdates = schedule.exdates
        .sort((a, b) => new Date(a) - new Date(b))
        .map(d => this._formatDate(d))
        .join(', ')

      exceptionsHtml = `<span class="rui-meta-info rui-meta-info--exceptions">${exceptLabel}: ${formattedExdates}</span>`    
    }

    let rdatesHtml = ""
    if (schedule.rdates && schedule.rdates.length > 0) {
      const rdateLabel = this.t('labels.rdates')
      const formattedRdates = schedule.rdates
        .sort((a, b) => new Date(a) - new Date(b))
        .map(d => this._formatDate(d))
        .join(', ')

      rdatesHtml = `<span class="rui-meta-info rui-meta-info--rdates">${rdateLabel}: ${formattedRdates}</span>`
    }
    let mainHtml = `<span class="rui-meta-info rui-meta-info--main">${mainText}</span>`

    this.summaryTextTarget.innerHTML = mainHtml + exceptionsHtml + rdatesHtml
  }

  // Updates the debug textarea with the current JSON from the hidden field
  updateDebugField() {
    if (this.hasIceCubeFieldTarget) {
      this.iceCubeFieldTarget.value = this.hiddenFieldTarget.value
    }
  }

  // Allows editing the JSON directly in the debug textarea
  updateHiddenFromDebug() {
    if (!this.hasIceCubeFieldTarget) return
    try {
      JSON.parse(this.iceCubeFieldTarget.value)
      this.hiddenFieldTarget.value = this.iceCubeFieldTarget.value
      this.initializeState()
    } catch (e) {
      // If the JSON is invalid, we can choose to ignore or show an error. For now, we'll just ignore it.
    }
  }

  // ==========================================
  // HELPERS & PRIVATE METHODS
  // ==========================================
  
  _buildSingleRuleHash(card) {
    const typeSelect = card.querySelector('[data-item="ruleType"]')
    if (!typeSelect) return null

    const ruleType = typeSelect.value
    // Если выбрано "Без повторения", это правило не идет в массив rrules
    if (ruleType === 'never' || !ruleType) return null

    const container = card.querySelector(`[data-item="specificFields"][data-rule="${ruleType}"]`)
    if (!container) return null

    const baseType = ruleType.split('_')[0]
    const iceCubeType = `IceCube::${baseType.charAt(0).toUpperCase()}${baseType.slice(1)}Rule`

    let ruleHash = {
      rule_type: iceCubeType,
      interval: parseInt(container.querySelector('[data-item="interval"]')?.value) || 1,
      validations: {}
    }

    if (ruleType === 'weekly') {
      const days = Array.from(container.querySelectorAll('[data-selected="true"]')).map(b => parseInt(b.dataset.value))
      if (days.length > 0) ruleHash.validations.day = days
    } else if (ruleType.endsWith('_day_of_month')) {
      const days = Array.from(container.querySelectorAll('[data-selected="true"]')).map(b => parseInt(b.dataset.day))
      if (days.length > 0) ruleHash.validations.day_of_month = days
    } else if (ruleType.endsWith('_by_weekday')) {
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

    // Termination for THIS card
    const endTypeSelect = card.querySelector('[data-item="endType"]')
    if (endTypeSelect) {
      const endType = endTypeSelect.value
      if (endType === 'until') {
        const endDateInput = card.querySelector('[data-item="endDateInput"]')
        if (endDateInput && endDateInput.value) ruleHash.until = endDateInput.value + "T23:59:59Z"
      } else if (endType === 'count') {
        const endCountInput = card.querySelector('[data-item="endCountInput"]')
        if (endCountInput && endCountInput.value) ruleHash.count = parseInt(endCountInput.value)
      }
    }

    if (Object.keys(ruleHash.validations).length === 0) delete ruleHash.validations
    return ruleHash
  }

  _createRuleCardFromHash(ruleHash) {

    if (!this.hasRuleCardTemplateTarget) return
    const content = this.ruleCardTemplateTarget.innerHTML
    this.rulesContainerTarget.insertAdjacentHTML('beforeend', content)

    const card = this.rulesContainerTarget.lastElementChild
    const ruleType = this._determineRuleType(ruleHash)
    
    const typeSelect = card.querySelector('[data-item="ruleType"]')
    if (typeSelect) typeSelect.value = ruleType

    this.toggleCardFields({ currentTarget: typeSelect })

    const container = card.querySelector(`[data-item="specificFields"][data-rule="${ruleType}"]`)
    if (container) {
      const intervalInput = container.querySelector('[data-item="interval"]')
      if (intervalInput && ruleHash.interval) intervalInput.value = ruleHash.interval

      if (ruleType.startsWith('yearly')) {
        const monthInput = container.querySelector('[data-item="month"]')
        if (monthInput && ruleHash.validations?.month_of_year) {
          monthInput.value = ruleHash.validations.month_of_year[0]
        }
      }

      this._syncButtonsFromHash(container, ruleHash)
    }

    this._fillTerminationFieldsForCard(card, ruleHash)
    // Card should be collapsed by default, so we don't show the body unless the user expands it
    const body = card.querySelector(`[data-${this.identifier}-target="cardBody"]`)
    if (body) {
      body.classList.add('hidden')
    }
    // Update header summary text for the card based on JSON data
    this.updateCardSummary(card)
  }
    

  _buildRuleSummaryText(hash) {
    const type = this._determineRuleType(hash)
    const interval = hash.interval || 1
    const vals = hash.validations || {}

    const intervalGender = (type === 'weekly') ? 'weekly_interval' : 'male'
    const count_f = this.formatOrdinal(interval, intervalGender)

    let termination = ""
    if (hash.until) {
      termination = this.t('until_label', { date: this._formatDate(hash.until.split('T')[0]) })
    } else if (hash.count) {
      termination = this.t('count_label', { count: hash.count })
    }

    let weekdays = ""
    if (vals.day || vals.day_of_week) {
      const listFormatter = new Intl.ListFormat(this.localeValue, { style: 'long', type: 'conjunction' })
      
      if (type === 'weekly' && vals.day) {
        const names = vals.day.map(i => this.translationsValue.weekdays?.day_names_plural?.[i])
        weekdays = listFormatter.format(names.filter(Boolean))
      } else if (vals.day_of_week) {
        const parts = Object.keys(vals.day_of_week).map(dayKey => {
          const dayIdx = parseInt(dayKey)
          const gender = this.translationsValue.weekdays?.weekday_genders?.[dayIdx] || 'male'
          
          const nths = vals.day_of_week[dayKey].map(n => {
            const nStr = n.toString()
            const genderSpecific = this.translationsValue.nth_names?.[gender]?.[nStr]
            if (genderSpecific) return genderSpecific

            const generalSpecific = this.translationsValue.nth_names?.[nStr]
            if (generalSpecific) return generalSpecific

            return this.formatOrdinal(n, gender)
          })
          
          return `${listFormatter.format(nths)} ${this.translationsValue.weekdays?.day_names?.[dayIdx]}`
        })
        weekdays = parts.join('; ')
      }
    }

    const month = (vals.month_of_year) ? 
      this.translationsValue.in_month_names_yearly?.[vals.month_of_year[0]] : ""

    let days_of_month = ""
    if (vals.day_of_month) {
      const formattedDates = vals.day_of_month.map(d => this.formatOrdinal(d, 'day_of_month'))
      const listFormatter = new Intl.ListFormat(this.localeValue, { style: 'long', type: 'conjunction' })
      days_of_month = this.t('days_of_month_fmt', { list: listFormatter.format(formattedDates) })
    }

    return this.t(`summary.${type}`, {
      count: interval,
      count_f: count_f,
      until: termination,
      weekdays: weekdays,
      month: month,
      days_of_month: days_of_month
    }).replace(/\s+/g, ' ').trim()
  }

  _determineRuleType(hash) {
    if (!hash || !hash.rule_type) return 'never'
    const base = hash.rule_type.replace('IceCube::', '').replace('Rule', '').toLowerCase()
    
    if (base === 'monthly') return hash.validations?.day_of_week ? 'monthly_by_weekday' : 'monthly_by_day_of_month'
    if (base === 'yearly') return hash.validations?.day_of_week ? 'yearly_by_weekday' : 'yearly_by_day_of_month'
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

  _fillTerminationFieldsForCard(card, hash) {
    const endTypeSelect = card.querySelector('[data-item="endType"]')
    if (!endTypeSelect) return

    if (hash.until) {
      endTypeSelect.value = 'until'
      const input = card.querySelector('[data-item="endDateInput"]')
      if (input) input.value = hash.until.split('T')[0]
    } else if (hash.count) {
      endTypeSelect.value = 'count'
      const input = card.querySelector('[data-item="endCountInput"]')
      if (input) input.value = hash.count
    } else {
      endTypeSelect.value = 'never'
    }

    this.toggleEndFields({ currentTarget: endTypeSelect })
  }

  _addDateToList(inputTarget, containerTarget, templateTarget) {
    const dateValue = inputTarget.value
    if (!dateValue) return

    const existingDates = Array.from(containerTarget.querySelectorAll('[data-date-value]')).map(el => el.dataset.dateValue)
    if (existingDates.includes(dateValue)) return

    const content = templateTarget.innerHTML
      .replace(/VALUE/g, dateValue)
      .replace(/LABEL/g, this._formatDate(dateValue))

    containerTarget.insertAdjacentHTML('beforeend', content)
    inputTarget.value = ""
    this.updateHiddenHash()
  }

  _fillDatesSection(container, template, datesArray) {
    if (!container || !template || !datesArray) return
    container.innerHTML = ""
    datesArray.forEach(dateValue => {
      const content = template.innerHTML
        .replace(/VALUE/g, dateValue)
        .replace(/LABEL/g, this._formatDate(dateValue))
      container.insertAdjacentHTML('beforeend', content)
    })
  }

  _getDatesArray(container, dataKey) {
    if (!container) return []
    return Array.from(container.children)
                .map(el => el.dataset[dataKey] || el.getAttribute(`data-${dataKey.replace(/([A-Z])/g, '-$1').toLowerCase()}`))
                .filter(Boolean)
  }

  syncButtonsUI() {
    if (!this.hasSelectedClasses) return
    this.element.querySelectorAll('[data-selected]').forEach(btn => btn.classList.remove(...this.selectedClasses))
    this.element.querySelectorAll('[data-selected="true"]').forEach(btn => btn.classList.add(...this.selectedClasses))
  }

  t(path, params = {}) {
    let result = path.split('.').reduce((o, i) => o ? o[i] : null, this.translationsValue)
    if (!result) return path

    const count = params.count ?? params.interval

    if (typeof count === 'number' && typeof result === 'object') {
      if (count === 1 && result['one']) {
        result = result['one']
      } else {
        const locale = this.localeValue || 'en'
        const pr = new Intl.PluralRules(locale, { type: 'cardinal' })
        const rule = pr.select(count)
        result = result[rule] || result['other'] || result['one'] || path
      }
    }

    if (typeof result !== 'string') return path

    Object.keys(params).forEach(key => {
      result = result.replace(`%{${key}}`, params[key])
    })

    return result
  }

  formatOrdinal(number, gender = 'male') {
    const locale = this.localeValue || 'en'
    const ruleType = locale.startsWith('en') ? 'ordinal' : 'cardinal'
    const pr = new Intl.PluralRules(locale, { type: ruleType })
    const rule = pr.select(number)

    const ordinals = this.translationsValue.ordinals || {}
    let template = null

    if (ordinals[gender] && typeof ordinals[gender] === 'object') {
      template = ordinals[gender][rule] || ordinals[gender]['other']
    }

    if (!template) {
      template = ordinals[rule] || ordinals['other']
    }

    if (typeof template !== 'string') return number.toString()

    return template.replace('%{count}', number)
  }

  _formatDate(dateString) {
    if (!dateString) return ''

    const [year, month, day] = dateString.split('T')[0].split('-').map(Number)
    const date = new Date(Date.UTC(year, month - 1, day))

    const y = date.getUTCFullYear()
    const m = date.getUTCMonth() + 1
    const d = date.getUTCDate()

    const dateConfig = this.translationsValue.date || {}
    const formatPattern = dateConfig.formats?.recurrence_date || "%Y-%m-%d"
    const monthNames = dateConfig.month_names || []
    const monthName = monthNames[m] || ""

    return formatPattern
      .replace(/%Y/g, y)
      .replace(/%-m/g, m)
      .replace(/%m/g, String(m).padStart(2, '0'))
      .replace(/%-d/g, d)
      .replace(/%d/g, String(d).padStart(2, '0'))
      .replace(/%B/g, monthName)
  }
}