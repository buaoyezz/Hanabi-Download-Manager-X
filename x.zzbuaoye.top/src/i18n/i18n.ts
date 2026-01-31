import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import en from './locales/en.json';
import zh from './locales/zh.json';

// 从 Cookie 读取语言偏好
const getStoredLanguage = (): string => {
  const cookies = document.cookie.split(';');
  for (const cookie of cookies) {
    const [name, value] = cookie.trim().split('=');
    if (name === 'hanabi_language') {
      return value;
    }
  }
  // 如果没有存储的语言，使用浏览器语言
  const browserLang = navigator.language.split('-')[0];
  return ['en', 'zh'].includes(browserLang) ? browserLang : 'en';
};

// 保存语言偏好到 Cookie（30天过期）
export const saveLanguagePreference = (lang: string) => {
  const expires = new Date();
  expires.setDate(expires.getDate() + 30);
  document.cookie = `hanabi_language=${lang};expires=${expires.toUTCString()};path=/;SameSite=Lax`;
};

const storedLanguage = getStoredLanguage();

i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: {
        translation: en,
      },
      zh: {
        translation: zh,
      },
    },
    lng: storedLanguage,
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false,
    },
  });

// 监听语言变化并保存到 Cookie
i18n.on('languageChanged', (lng) => {
  saveLanguagePreference(lng);
});

export default i18n;
