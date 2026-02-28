/**
 * Wiki Lazy Loader
 * Утилита для отложенной загрузки библиотек Wiki редактора.
 * Загружает библиотеки только когда они действительно нужны.
 */

const WikiLazyLoader = {
  // Состояние загрузки библиотек
  loaded: {
    marked: false,
    hljs: false,
    katex: false,
    mermaid: false,
    dompurify: false,
    easymde: false
  },
  
  // Промисы загрузки (для предотвращения дублирования)
  loading: {
    marked: null,
    hljs: null,
    katex: null,
    mermaid: null,
    dompurify: null,
    easymde: null
  },
  
  // CDN URLs
  urls: {
    marked: 'https://cdn.jsdelivr.net/npm/marked/marked.min.js',
    hljs: {
      css: 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css',
      js: 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js'
    },
    katex: {
      css: 'https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css',
      js: 'https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js',
      autoRender: 'https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js'
    },
    dompurify: 'https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.0.6/purify.min.js',
    easymde: {
      css: 'https://cdn.jsdelivr.net/npm/easymde/dist/easymde.min.css',
      js: 'https://cdn.jsdelivr.net/npm/easymde/dist/easymde.min.js'
    }
  },

  /**
   * Загружает скрипт динамически
   * @param {string} url - URL скрипта
   * @returns {Promise<void>}
   */
  loadScript(url) {
    return new Promise((resolve, reject) => {
      // Проверяем, не загружен ли уже скрипт
      const existing = document.querySelector(`script[src="${url}"]`);
      if (existing) {
        resolve();
        return;
      }
      
      const script = document.createElement('script');
      script.src = url;
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error(`Failed to load script: ${url}`));
      document.head.appendChild(script);
    });
  },

  /**
   * Загружает CSS динамически
   * @param {string} url - URL стилей
   * @returns {Promise<void>}
   */
  loadStyle(url) {
    return new Promise((resolve, reject) => {
      // Проверяем, не загружен ли уже стиль
      const existing = document.querySelector(`link[href="${url}"]`);
      if (existing) {
        resolve();
        return;
      }
      
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = url;
      link.onload = () => resolve();
      link.onerror = () => reject(new Error(`Failed to load style: ${url}`));
      document.head.appendChild(link);
    });
  },

  /**
   * Загружает Marked.js (Markdown парсер)
   * @returns {Promise<void>}
   */
  async loadMarked() {
    if (this.loaded.marked) return;
    if (this.loading.marked) return this.loading.marked;
    
    this.loading.marked = this.loadScript(this.urls.marked);
    await this.loading.marked;
    this.loaded.marked = true;
    this.loading.marked = null;
  },

  /**
   * Загружает Highlight.js (подсветка кода)
   * @returns {Promise<void>}
   */
  async loadHighlightJS() {
    if (this.loaded.hljs) return;
    if (this.loading.hljs) return this.loading.hljs;
    
    this.loading.hljs = Promise.all([
      this.loadStyle(this.urls.hljs.css),
      this.loadScript(this.urls.hljs.js)
    ]);
    
    await this.loading.hljs;
    this.loaded.hljs = true;
    this.loading.hljs = null;
  },

  /**
   * Загружает KaTeX (математические формулы)
   * @returns {Promise<void>}
   */
  async loadKaTeX() {
    if (this.loaded.katex) return;
    if (this.loading.katex) return this.loading.katex;
    
    this.loading.katex = Promise.all([
      this.loadStyle(this.urls.katex.css),
      this.loadScript(this.urls.katex.js),
      this.loadScript(this.urls.katex.autoRender)
    ]);
    
    await this.loading.katex;
    this.loaded.katex = true;
    this.loading.katex = null;
  },

  /**
   * Загружает DOMPurify (защита от XSS)
   * @returns {Promise<void>}
   */
  async loadDOMPurify() {
    if (this.loaded.dompurify) return;
    if (this.loading.dompurify) return this.loading.dompurify;
    
    this.loading.dompurify = this.loadScript(this.urls.dompurify);
    await this.loading.dompurify;
    this.loaded.dompurify = true;
    this.loading.dompurify = null;
  },

  /**
   * Загружает EasyMDE (редактор)
   * @returns {Promise<void>}
   */
  async loadEasyMDE() {
    if (this.loaded.easymde) return;
    if (this.loading.easymde) return this.loading.easymde;
    
    this.loading.easymde = Promise.all([
      this.loadStyle(this.urls.easymde.css),
      this.loadScript(this.urls.easymde.js)
    ]);
    
    await this.loading.easymde;
    this.loaded.easymde = true;
    this.loading.easymde = null;
  },

  /**
   * Проверяет, содержит ли текст формулы KaTeX
   * @param {string} text - Markdown текст
   * @returns {boolean}
   */
  hasKaTeX(text) {
    if (!text) return false;
    // Ищем $...$ или $$...$$
    return /\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$/.test(text);
  },

  /**
   * Проверяет, содержит ли текст Mermaid диаграммы
   * @param {string} text - Markdown текст
   * @returns {boolean}
   */
  hasMermaid(text) {
    if (!text) return false;
    return /```mermaid[\s\S]*?```/.test(text);
  },

  /**
   * Проверяет, содержит ли текст код-блоки
   * @param {string} text - Markdown текст
   * @returns {boolean}
   */
  hasCodeBlocks(text) {
    if (!text) return false;
    return /```[a-zA-Z]+\n[\s\S]*?```/.test(text);
  },

  /**
   * Загружает все необходимые библиотеки на основе контента
   * @param {string} text - Markdown текст
   * @returns {Promise<void>}
   */
  async loadForContent(text) {
    const promises = [];
    
    // Всегда нужны: marked, dompurify
    promises.push(this.loadMarked());
    promises.push(this.loadDOMPurify());
    
    // Условная загрузка
    if (this.hasCodeBlocks(text)) {
      promises.push(this.loadHighlightJS());
    }
    
    if (this.hasKaTeX(text)) {
      promises.push(this.loadKaTeX());
    }
    
    // Mermaid загружается через importmap, только инициализируем
    // Проверка наличия mermaid в window происходит в renderMarkdown
    
    await Promise.all(promises);
  },

  /**
   * Предзагружает критичные библиотеки (для улучшения UX)
   * Вызывать при наведении на кнопку открытия редактора
   */
  preloadCritical() {
    // Загружаем в фоне, не блокируя
    this.loadMarked().catch(() => {});
    this.loadDOMPurify().catch(() => {});
  },

  /**
   * Сбрасывает состояние (полезно при тестировании)
   */
  reset() {
    this.loaded = {
      marked: false,
      hljs: false,
      katex: false,
      mermaid: false,
      dompurify: false,
      easymde: false
    };
    this.loading = {
      marked: null,
      hljs: null,
      katex: null,
      mermaid: null,
      dompurify: null,
      easymde: null
    };
  }
};

// Экспортируем в глобальную область для совместимости
window.WikiLazyLoader = WikiLazyLoader;

export default WikiLazyLoader;