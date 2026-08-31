(function () {
  'use strict';

  if (window.__CLASHFX_DASHBOARD_COMPAT__) return;
  window.__CLASHFX_DASHBOARD_COMPAT__ = true;

  var themePalette = {
    light: { base: '#fff', primary: '#422ad5', content: '#18181b' },
    dark: { base: '#1d232a', primary: '#605dff', content: '#f2f8ff' },
    cupcake: { base: '#faf7f5', primary: '#44ebd3', content: '#291334' },
    bumblebee: { base: '#fff', primary: '#f7c800', content: '#161616' },
    emerald: { base: '#fff', primary: '#66cc8a', content: '#333c4d' },
    corporate: { base: '#fff', primary: '#0082c4', content: '#181a2a' },
    synthwave: { base: '#09002f', primary: '#f861b4', content: '#a2b2ff' },
    retro: { base: '#ece3ca', primary: '#ff9fa0', content: '#793205' },
    cyberpunk: { base: '#fff25a', primary: '#ff7299', content: '#000' },
    valentine: { base: '#fcf2f8', primary: '#f43098', content: '#c2005b' },
    halloween: { base: '#1b1816', primary: '#ff960c', content: '#cdcdcd' },
    garden: { base: '#e9e7e7', primary: '#f80076', content: '#100f0f' },
    forest: { base: '#1b1717', primary: '#1fb854', content: '#cac9c9' },
    aqua: { base: '#1a368b', primary: '#13ecf3', content: '#b8e6fe' },
    lofi: { base: '#fff', primary: '#0d0d0d', content: '#000' },
    pastel: { base: '#fff', primary: '#e8d4ff', content: '#161616' },
    fantasy: { base: '#fff', primary: '#6b0072', content: '#1f2937' },
    wireframe: { base: '#fff', primary: '#d4d4d4', content: '#161616' },
    black: { base: '#000', primary: '#3a3a3a', content: '#d6d6d6' },
    luxury: { base: '#09090b', primary: '#fff', content: '#dca54d' },
    dracula: { base: '#282a36', primary: '#ff79c6', content: '#f8f8f3' },
    cmyk: { base: '#fff', primary: '#45aeee', content: '#161616' },
    autumn: { base: '#f1f1f1', primary: '#8c0327', content: '#141414' },
    business: { base: '#202020', primary: '#1c4e80', content: '#cdcdcd' },
    acid: { base: '#f8f8f8', primary: '#ff24fb', content: '#000' },
    lemonade: { base: '#f8fdef', primary: '#4b9200', content: '#151614' },
    night: { base: '#0f172a', primary: '#3abdf7', content: '#c9cbd0' },
    coffee: { base: '#261b25', primary: '#db924c', content: '#c59f61' },
    winter: { base: '#fff', primary: '#006ef6', content: '#394e6a' },
    dim: { base: '#2a303c', primary: '#9fe88d', content: '#b2ccd6' },
    nord: { base: '#eceff4', primary: '#5e81ac', content: '#2e3440' },
    sunset: { base: '#121c22', primary: '#ff865b', content: '#9fb9d0' },
    caramellatte: { base: '#fff7ed', primary: '#000', content: '#7c2808' },
    abyss: { base: '#001b20', primary: '#c2fd00', content: '#ffd6a7' },
    silk: { base: '#f7f5f3', primary: '#1c1c29', content: '#4b4743' }
  };

  // MetaCubeXD used to synchronously force style calculation for every theme
  // whenever the picker opened. Return its build-time palette without layout.
  var nativeGetComputedStyle = window.getComputedStyle.bind(window);
  window.getComputedStyle = function (element, pseudoElement) {
    var themeName = element && element.getAttribute && element.getAttribute('data-theme');
    var palette = themeName && themePalette[themeName];
    var isThemeProbe = palette && !pseudoElement && element.style &&
      element.style.position === 'absolute' && element.style.visibility === 'hidden' &&
      element.style.pointerEvents === 'none';
    if (isThemeProbe) {
      return {
        getPropertyValue: function (propertyName) {
          if (propertyName === '--color-base-100') return palette.base;
          if (propertyName === '--color-primary') return palette.primary;
          if (propertyName === '--color-base-content') return palette.content;
          return '';
        }
      };
    }
    return nativeGetComputedStyle(element, pseudoElement);
  };

  var supportsColorMix = window.CSS && window.CSS.supports &&
    window.CSS.supports('color', 'color-mix(in oklab, currentColor 50%, transparent)');
  if (supportsColorMix) return;

  function installLegacyColorFallbacks() {
    var root = document.documentElement;
    if (!root) return;

    var styleID = 'clashfx-legacy-color-fallbacks';
    var utilityClasses = {};
    var rebuildScheduled = false;
    var probe = document.createElement('span');
    probe.setAttribute('aria-hidden', 'true');
    probe.style.position = 'absolute';
    probe.style.visibility = 'hidden';
    probe.style.pointerEvents = 'none';
    root.appendChild(probe);

    function rgbaFor(variableName, alpha) {
      probe.style.color = '';
      probe.style.color = 'var(' + variableName + ')';
      var value = nativeGetComputedStyle(probe).color || '';
      var match = value.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i);
      if (!match) return 'rgba(0, 0, 0, ' + alpha + ')';
      return 'rgba(' + Math.round(Number(match[1])) + ', ' +
        Math.round(Number(match[2])) + ', ' + Math.round(Number(match[3])) + ', ' + alpha + ')';
    }

    function addUtilityClass(className) {
      var match = className.match(/^(bg|text|border|border-r)-([a-z0-9-]+)\/(\d+)(!)?$/i);
      if (!match || match[2] === 'current') return false;
      if (utilityClasses[className]) return false;
      utilityClasses[className] = {
        property: match[1] === 'bg' ? 'background-color' :
          (match[1] === 'text' ? 'color' :
            (match[1] === 'border-r' ? 'border-right-color' : 'border-color')),
        variable: '--color-' + match[2],
        alpha: Math.min(100, Number(match[3])) / 100
      };
      return true;
    }

    function collectUtilityClasses(node) {
      var changed = false;
      if (node.nodeType !== 1) return changed;
      var elements = [node];
      var descendants = node.querySelectorAll ? node.querySelectorAll('[class]') : [];
      for (var i = 0; i < descendants.length; i++) elements.push(descendants[i]);
      for (var elementIndex = 0; elementIndex < elements.length; elementIndex++) {
        var classes = elements[elementIndex].classList;
        if (!classes) continue;
        for (var classIndex = 0; classIndex < classes.length; classIndex++) {
          if (addUtilityClass(classes.item(classIndex))) changed = true;
        }
      }
      return changed;
    }

    function buildConnectionRules() {
      var content = function (alpha) { return rgbaFor('--color-base-content', alpha); };
      var primary = function (alpha) { return rgbaFor('--color-primary', alpha); };
      var error = function (alpha) { return rgbaFor('--color-error', alpha); };
      return [
        '.conn-table-container{--conn-border:' + content(0.10) + '!important}',
        '.conn-th{color:' + content(0.70) + '!important}',
        '.conn-group-btn,.conn-group-count,.conn-card-group-count,.conn-empty,.conn-td-label{color:' + content(0.50) + '!important}',
        '.conn-group-btn:hover,.conn-copy-btn:hover{background:' + primary(0.10) + '!important}',
        '.conn-group-row,.conn-card-group{background:' + primary(0.05) + '!important}',
        '.conn-group-row:hover,.conn-card-group:hover{background:' + primary(0.10) + '!important}',
        '.conn-group-icon,.conn-card-group-icon{background:' + primary(0.15) + '!important}',
        '.conn-data-row:nth-child(2n){background:' + content(0.02) + '!important}',
        '.conn-data-row:hover{background:' + content(0.05) + '!important}',
        '.conn-td{border-bottom-color:' + content(0.05) + '!important}',
        '.conn-card{border-color:' + content(0.08) + '!important}',
        '.conn-card:hover{border-color:' + content(0.15) + '!important}',
        '.conn-card__process{color:' + content(0.75) + '!important}',
        '.conn-card__aux,.conn-aux{color:' + content(0.58) + '!important}',
        '.conn-copy-btn{color:' + content(0.45) + '!important}',
        '.conn-close-btn{background:' + error(0.10) + '!important}',
        '.conn-close-btn:hover{background:' + error(0.20) + '!important}'
      ];
    }

    function rebuildStyles() {
      rebuildScheduled = false;
      var existingStyle = document.getElementById(styleID);
      if (existingStyle) existingStyle.remove();
      var style = document.createElement('style');
      style.id = styleID;
      var rules = buildConnectionRules();
      Object.keys(utilityClasses).forEach(function (className) {
        var descriptor = utilityClasses[className];
        var escapedName = className.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
        rules.push('html [class~="' + escapedName + '"]{' + descriptor.property + ':' +
          rgbaFor(descriptor.variable, descriptor.alpha) + '!important}');
      });
      style.textContent = rules.join('\n');
      (document.head || root).appendChild(style);
    }

    function scheduleRebuild() {
      if (rebuildScheduled) return;
      rebuildScheduled = true;
      window.requestAnimationFrame(rebuildStyles);
    }

    collectUtilityClasses(root);
    rebuildStyles();

    new MutationObserver(function (mutations) {
      var changed = false;
      for (var i = 0; i < mutations.length; i++) {
        for (var j = 0; j < mutations[i].addedNodes.length; j++) {
          if (collectUtilityClasses(mutations[i].addedNodes[j])) changed = true;
        }
      }
      if (changed) scheduleRebuild();
    }).observe(root, { childList: true, subtree: true });

    new MutationObserver(scheduleRebuild).observe(root, {
      attributes: true,
      attributeFilter: ['data-theme']
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', installLegacyColorFallbacks);
  } else {
    installLegacyColorFallbacks();
  }
})();
