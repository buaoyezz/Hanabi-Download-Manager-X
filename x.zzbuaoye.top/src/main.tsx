import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';
import App from './App';
import { pushService } from './services/pushService';
import { websocketService } from './services/websocketService';
import './i18n/i18n';
import './index.css';

// 初始化推送服务
pushService.initialize().then((initialized) => {
  if (initialized) {
    console.log('Push service initialized successfully');
  }
});

// 初始化WebSocket连接（仅在生产环境）
if (import.meta.env.PROD) {
  websocketService.connect();
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <FluentProvider theme={webLightTheme}>
        <App />
      </FluentProvider>
    </BrowserRouter>
  </React.StrictMode>,
);
