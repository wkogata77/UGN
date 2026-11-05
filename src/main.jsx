import React, { lazy, Suspense } from 'react';
import { createRoot } from 'react-dom/client';
import './style.css';

const App = lazy(() =>
  new URLSearchParams(window.location.search).get('demo') === 'depth'
    ? import('./demo/DepthDemo.jsx')
    : import('./App.jsx'),
);

createRoot(document.getElementById('root')).render(
  <Suspense fallback={<div role="status">Loading Field Command...</div>}>
    <App />
  </Suspense>,
);
