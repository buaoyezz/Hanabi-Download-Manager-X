import React from 'react';
import ReactDOM from 'react-dom/client';
import { FluentProvider } from '@fluentui/react-components';
import { hanabiTheme } from '@/lib/theme';
import App from './App.tsx';
import './style.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <FluentProvider theme={hanabiTheme}>
      <App />
    </FluentProvider>
  </React.StrictMode>,
);
