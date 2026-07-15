(function () {
  // Resolve what actual theme (light/dark) should be rendered by the JTD engine
  function resolveEngineTheme(storedState) {
    if (!storedState || storedState === 'system') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return storedState; // returns 'light' or 'dark'
  }

  // Main function to update UI text and apply colors
  function applyThemeState(state) {
    const toggleBtn = document.getElementById('theme-toggle');
    const actualTheme = resolveEngineTheme(state);

    // Set Jekyll-Just-The-Docs core theme
    jtd.setTheme(actualTheme);

    // Update the button UI label based on the chosen preference
    if (toggleBtn) {
      if (!state || state === 'system') {
        toggleBtn.innerHTML = '🌓';
        toggleBtn.setAttribute('title', 'Theme: Automatic (System)');
      } else if (state === 'dark') {
        toggleBtn.innerHTML = '🌙';
        toggleBtn.setAttribute('title', 'Theme: Dark');
      } else {
        toggleBtn.innerHTML = '☀️';
        toggleBtn.setAttribute('title', 'Theme: Light');
      }
    }
  }

  // Execute immediately to prevent page flash before DOM loads
  const initialSavedState = localStorage.getItem('theme-preference') || 'system';
  applyThemeState(initialSavedState);

  // Attach interactive event loop after DOM completes loading
  window.addEventListener('DOMContentLoaded', () => {
    const toggleBtn = document.getElementById('theme-toggle');

    // Refresh button immediately in case DOM rendering broke execution
    const currentPreference = localStorage.getItem('theme-preference') || 'system';
    applyThemeState(currentPreference);

    if (toggleBtn) {
      jtd.addEvent(toggleBtn, 'click', function () {
        const activePreference = localStorage.getItem('theme-preference') || 'system';
        let nextPreference;

        // Loop mechanics: System -> Light -> Dark -> System
        if (activePreference === 'system') {
          nextPreference = 'light';
        } else if (activePreference === 'light') {
          nextPreference = 'dark';
        } else {
          nextPreference = 'system';
        }

        // Save preference state and update layout
        localStorage.setItem('theme-preference', nextPreference);
        applyThemeState(nextPreference);
      });
    }

    // Continuously listen to system switches in the background
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      const activePreference = localStorage.getItem('theme-preference') || 'system';
      if (activePreference === 'system') {
        applyThemeState('system');
      }
    });
  });
})();
