const languageButton = document.getElementById('language-switch');
const originalTitle = document.title;
const translatable = [...document.querySelectorAll('[data-en]')];
for (const node of translatable) node.dataset.zh = node.textContent;
let language = 'zh';
try { if (localStorage.getItem('quiet-campus-language') === 'en') language = 'en'; } catch { /* Optional preference only. */ }

function renderLanguage() {
  const english = language === 'en';
  document.documentElement.lang = english ? 'en' : 'zh-CN';
  document.title = english ? document.documentElement.dataset.enTitle : originalTitle;
  for (const node of translatable) node.textContent = english ? node.dataset.en : node.dataset.zh;
  languageButton.textContent = english ? '中文' : 'English';
  languageButton.setAttribute('aria-label', english ? 'Switch to Chinese' : '切换到英文');
  for (const id of ['guide-link', 'footer-guide']) document.getElementById(id).href = english ? 'guide.en.html' : 'guide.zh-CN.html';
  const today = new Date();
  document.getElementById('calendar-month').textContent = `${today.getFullYear()} / ${String(today.getMonth() + 1).padStart(2, '0')}`;
  document.getElementById('calendar-day').textContent = String(today.getDate()).padStart(2, '0');
  document.getElementById('calendar-weekday').textContent = new Intl.DateTimeFormat(english ? 'en' : 'zh-CN', {weekday:'short'}).format(today);
}
languageButton.addEventListener('click', () => {
  language = language === 'en' ? 'zh' : 'en';
  try { localStorage.setItem('quiet-campus-language', language); } catch { /* Keep the in-page choice. */ }
  renderLanguage();
});
document.getElementById('local-only').hidden = !['127.0.0.1', 'localhost', '::1', '[::1]'].includes(location.hostname);
renderLanguage();
