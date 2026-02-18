/**
 * Mermaid Configuration Module
 * @description Конфигурация Mermaid для тёмной темы проекта
 * @version 1.0.0
 * 
 * Исправляет проблему с stroke="none" на линиях сообщений в sequence-диаграммах
 * через themeCSS, который внедряется напрямую в SVG.
 */

import mermaid from "mermaid";

// Инициализация Mermaid с настройками проекта
mermaid.initialize({
  startOnLoad: false,
  theme: 'dark',
  
  // === ПЕРЕМЕННЫЕ ТЕМЫ ===
  themeVariables: {
    // === ЦВЕТОВАЯ СХЕМА БЕЗ ГРАДИЕНТОВ ===
    // Фон: тёмный для контраста
    background: '#1f2937',
    // Узлы: серый с чёткими границами
    primaryColor: '#374151',
    primaryBorderColor: '#4b5563',
    primaryTextColor: '#ffffff',
    // Рёбра: контрастные линии
    lineColor: '#9ca3af',
    // Текст: максимальная читаемость
    nodeTextColor: '#ffffff',
    // Акцент: фирменный amber-400
    titleColor: '#fbbf24',
    // Кластеры/группы
    clusterBkg: '#1f2937',
    clusterBorder: '#4b5563',
    
    // === SEQUENCE DIAGRAM ===
    // Актёры: тёмный фон, белый текст, контрастные границы
    actorBkg: '#374151',
    actorBorder: '#4b5563',
    actorTextColor: '#ffffff',
    // Линии сообщений: контрастные
    actorLineColor: '#9ca3af',
    // Номера последовательностей: акцент
    sequenceNumberColor: '#fbbf24',
    // Сигналы
    signalColor: '#9ca3af',
    signalTextColor: '#ffffff',
    
    // === GANTT ===
    altBackgroundColor: '#f59e0b',
    altBackgroundColor2: '#374151',
    altBackgroundColor3: '#b91c1c',
    
    // === ТИПОГРАФИКА ===
    fontFamily: 'Inter, system-ui, -apple-system, sans-serif',
    fontSize: '14px'
  },
  
  // === CRITICAL: CSS для исправления stroke="none" ===
  // themeCSS внедряется напрямую в SVG и имеет приоритет над атрибутами
  themeCSS: `
    /* Линии сообщений в sequence-диаграммах */
    .messageLine0, .messageLine1 { 
      stroke: #9ca3af !important; 
      stroke-width: 2px !important; 
    }
    .messageLine0 { 
      stroke-dasharray: none !important; 
    }
    .messageLine1 { 
      stroke-dasharray: 6, 3 !important; 
    }
    /* Линии циклов и альтернативных блоков */
    .loopLine { 
      stroke: #9ca3af !important; 
      stroke-width: 2px !important; 
      stroke-dasharray: 6, 3 !important; 
    }
    /* Вертикальные линии актёров */
    .actor-line { 
      stroke: #9ca3af !important; 
    }
  `,
  
  // === КОНФИГУРАЦИЯ ДИАГРАММ ===
  flowchart: {
    curve: 'basis',
    padding: 24,
    nodeSpacing: 80,
    rankSpacing: 60,
    useMaxWidth: true
  },
  
  sequence: {
    actorMargin: 60,
    boxMargin: 12,
    boxTextMargin: 8,
    noteMargin: 12,
    messageMargin: 40,
    mirrorActors: true,
    useMaxWidth: true,
    // Явно указываем цвет линий сообщений
    messageLineColor: '#9ca3af'
  },
  
  gantt: {
    leftPadding: 80,
    gridLineStartPadding: 40,
    barHeight: 24,
    barGap: 6,
    topPadding: 60,
    useMaxWidth: true
  }
});

// Экспортируем настроенный mermaid
export default mermaid;

/**
 * Рендерит Mermaid диаграмму
 * @param {string} code - Код диаграммы Mermaid
 * @returns {Promise<string|null>} SVG строка или null при ошибке
 */
export async function renderMermaidDiagram(code) {
  const id = 'mermaid-' + Math.random().toString(36).slice(2, 11);
  
  try {
    // Сбрасываем кэш для чистого рендеринга
    if (mermaid.reset) {
      mermaid.reset();
    }
    
    const { svg } = await mermaid.render(id, code.trim());
    return svg;
  } catch (error) {
    console.error('Mermaid render error:', error);
    return null;
  }
}

/**
 * Рендерит все Mermaid диаграммы в контейнере
 * @param {HTMLElement} container - Контейнер с элементами .mermaid-source
 * @returns {Promise<void>}
 */
export async function renderAllMermaidDiagrams(container) {
  const mermaidCodes = container.querySelectorAll('pre.mermaid-source code.language-mermaid');
  
  for (const codeBlock of mermaidCodes) {
    const pre = codeBlock.parentNode;
    const graphDefinition = codeBlock.textContent.trim();
    
    const svgContent = await renderMermaidDiagram(graphDefinition);
    
    if (svgContent) {
      const div = document.createElement('div');
      div.className = 'mermaid-diagram';
      div.innerHTML = svgContent;
      
      if (pre.parentNode) {
        pre.parentNode.replaceChild(div, pre);
      }
    } else {
      // Показываем ошибку
      const errorDiv = document.createElement('div');
      errorDiv.className = 'mermaid-error';
      errorDiv.innerHTML = `
        <div class="error-header">
          <i class="fa fa-exclamation-triangle"></i> Ошибка Mermaid
        </div>
        <div class="error-details">Не удалось отрендерить диаграмму</div>
        <details>
          <summary>Код диаграммы</summary>
          <pre>${escapeHtml(graphDefinition)}</pre>
        </details>
      `;
      if (pre && pre.parentNode) {
        pre.parentNode.replaceChild(errorDiv, pre);
      }
    }
  }
}

/**
 * Экранирование HTML-символов
 * @param {string} text - Текст для экранирования
 * @returns {string} Экранированный текст
 */
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
