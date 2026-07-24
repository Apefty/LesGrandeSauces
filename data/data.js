/* <!-- ANDROID VERSION! --> */
/* build 1.6.0 — 2026-07-22 */

// data/data.js
// Only lazy-load helpers + fetch bootstrap live here now.
// Category tree / usage / icon dictionaries live in data/data.json.
// Each sauce is loaded on demand from data/sauces/<slug>.js

window.SD = { r: {} };

window.SD._saucesBasePath = (function () {
  if (typeof document !== 'undefined' && document.currentScript && document.currentScript.src) {
    return document.currentScript.src.replace(/[^/]*$/, '') + 'sauces/';
  }
  return './data/sauces/';
})();

window.SD._dataJsonPath = (function () {
  if (typeof document !== 'undefined' && document.currentScript && document.currentScript.src) {
    return document.currentScript.src.replace(/[^/]*$/, '') + 'data.json';
  }
  return './data/data.json';
})();

function _slug(name) {
  return String(name)
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')  // é/è/ç etc. → e/e/c (strip accents, keep the base letter)
    .toLowerCase()
    .replace(/[\s-]+/g, '_')   // spaces AND hyphens → underscore
    .replace(/[^a-z0-9_]/g, '');
}

window.SD.loadSauce = async function (name) {
  if (!name) throw new Error('sauce name required');
  if (window.SD.r[name]) return window.SD.r[name];
  const slug = _slug(name);
  const path = window.SD._saucesBasePath + slug + '.js';
  try {
    const mod = await import(path);
    const data = mod.default || mod;
    const key = Object.keys(data)[0];
    window.SD.r[key] = data[key];
    return window.SD.r[key];
  } catch (err) {
    console.error('Failed loading sauce:', name, path, err);
    throw err;
  }
};

window.SD.loadSauces = async function (list) {
  if (!Array.isArray(list)) return Promise.reject(new Error('provide array of sauce names'));
  return Promise.all(list.map(n => window.SD.loadSauce(n)));
};

// ── Словник українських назв (будується з s_uk у кожному sub) ─────────
// Щоб додати переклад назви соусу для списків (Ієрархія / Всі соуси),
// допишіть паралельний масив s_uk поруч із s у потрібному підрозділі
// (той самий порядок і довжина; порожній рядок "" = показати англійську).
function _buildNameUk() {
  window.SD.nameUk = {};
  window.SD.cats.forEach(function (cat) {
    cat.subs.forEach(function (sub) {
      if (sub.s_uk) {
        sub.s.forEach(function (nm, i) {
          if (sub.s_uk[i]) window.SD.nameUk[nm] = sub.s_uk[i];
        });
      }
    });
  });
}

// ── Bootstrap: fetch data.json (cats/usage/cico/uico/tico) ────────────
// app.js's DOMContentLoaded handler awaits this before calling initApp().
window.SD_READY = fetch(window.SD._dataJsonPath)
  .then(function (res) {
    if (!res.ok) throw new Error('Failed to fetch data.json: ' + res.status);
    return res.json();
  })
  .then(function (json) {
    window.SD.cats = json.cats;
    window.SD.usage = json.usage;
    window.SD.cico = json.cico;
    window.SD.uico = json.uico;
    window.SD.tico = json.tico;
    _buildNameUk();
    return window.SD;
  })
  .catch(function (err) {
    console.error('Failed loading data.json:', err);
    throw err;
  });
