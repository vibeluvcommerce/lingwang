/* ==========================================================================
   main.js —— 导航抽屉 / 滚动显现 / 表单校验
   全站正文与关键信息均为静态 HTML，JS 只做增强，不承担渲染
   ========================================================================== */

(function () {
  'use strict';

  var doc = document;
  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------------------------------------------------------------- 导航 */
  var toggle = doc.querySelector('.nav-toggle');
  var nav = doc.getElementById('nav');

  if (toggle && nav) {
    var closeNav = function () {
      nav.classList.remove('is-open');
      toggle.setAttribute('aria-expanded', 'false');
      doc.body.style.overflow = '';
    };

    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', String(open));
      doc.body.style.overflow = open ? 'hidden' : '';
    });

    nav.addEventListener('click', function (e) {
      if (e.target.closest('a')) closeNav();
    });

    doc.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && nav.classList.contains('is-open')) {
        closeNav();
        toggle.focus();
      }
    });

    window.addEventListener('resize', function () {
      if (window.innerWidth > 768 && nav.classList.contains('is-open')) closeNav();
    });
  }

  /* ------------------------------------------------------------ 顶栏阴影 */
  var head = doc.querySelector('.site-head');
  if (head) {
    var ticking = false;
    var onScroll = function () {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(function () {
        head.classList.toggle('is-stuck', window.scrollY > 12);
        ticking = false;
      });
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  /* ------------------------------------------------------------ 滚动显现 */
  var targets = doc.querySelectorAll('[data-reveal]');

  if (targets.length) {
    if (reduced || !('IntersectionObserver' in window)) {
      Array.prototype.forEach.call(targets, function (el) {
        el.classList.add('is-in');
      });
    } else {
      var io = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              entry.target.classList.add('is-in');
              io.unobserve(entry.target);
            }
          });
        },
        { rootMargin: '0px 0px -12% 0px', threshold: 0.12 }
      );
      Array.prototype.forEach.call(targets, function (el) {
        io.observe(el);
      });
    }
  }

  /* -------------------------------------------------------------- 表单 */
  var form = doc.getElementById('consult-form');
  if (!form) return;

  var receiptEl = doc.getElementById('receipt-id');
  var successEl = doc.getElementById('form-success');
  var alertEl = doc.getElementById('form-alert');
  var submitBtn = form.querySelector('button[type="submit"]');
  var startedAt = Date.now();

  var RULES = {
    name: function (v) {
      var s = v.trim();
      if (!s) return '请填写您的称呼';
      if (s.length < 2 || s.length > 20) return '称呼请填写 2–20 个字';
      if (/https?:\/\/|www\.|\.com|\.cn/i.test(s)) return '请勿填写网址';
      if (/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u.test(s)) return '请勿填写表情符号';
      return '';
    },
    phone: function (v) {
      var s = v.trim();
      if (!s) return '请填写手机号，便于我们回电';
      if (!/^1[3-9]\d{9}$/.test(s)) return '手机号格式不正确，请检查后重填';
      return '';
    },
    identity: function (v) {
      return v ? '' : '请选择您的身份，便于安排对应团队回电';
    },
    message: function (v) {
      var s = v.trim();
      if (!s) return '请用一句话描述您遇到的情况';
      if (s.length < 10) return '请至少填写 10 个字，太简短我们难以判断';
      if (s.length > 500) return '请控制在 500 字以内（当前 ' + s.length + ' 字）';
      if (/保证胜诉|包赢|百分百胜诉|100%胜诉/.test(s)) {
        return '请避免使用“保证胜诉”类表述：律师不得承诺案件结果，我们改为描述事实与诉求即可';
      }
      return '';
    },
    agree: function (_, input) {
      return input.checked ? '' : '请先阅读并同意隐私告知';
    }
  };

  function fieldOf(input) {
    return input.closest('.field') || input.closest('.check');
  }

  function showError(input, msg) {
    var wrap = fieldOf(input);
    if (!wrap) return;
    wrap.classList.add('is-invalid');
    var box = wrap.querySelector('.err');
    if (box) box.textContent = msg;
    input.setAttribute('aria-invalid', 'true');
  }

  function clearError(input) {
    var wrap = fieldOf(input);
    if (!wrap) return;
    wrap.classList.remove('is-invalid');
    input.removeAttribute('aria-invalid');
  }

  function validateField(input) {
    var rule = RULES[input.name];
    if (!rule) return true;
    var msg = rule(input.value, input);
    if (msg) {
      showError(input, msg);
      return false;
    }
    clearError(input);
    return true;
  }

  var fields = form.querySelectorAll('[name]');

  Array.prototype.forEach.call(fields, function (input) {
    if (!RULES[input.name]) return;
    input.addEventListener('blur', function () {
      validateField(input);
    });
    input.addEventListener('input', function () {
      var wrap = fieldOf(input);
      if (wrap && wrap.classList.contains('is-invalid')) validateField(input);
    });
    input.addEventListener('change', function () {
      if (input.type === 'checkbox' || input.tagName === 'SELECT') validateField(input);
    });
  });

  form.addEventListener('submit', function (e) {
    e.preventDefault();

    if (alertEl) {
      alertEl.hidden = true;
      alertEl.textContent = '';
    }

    var firstBad = null;
    Array.prototype.forEach.call(fields, function (input) {
      if (!RULES[input.name]) return;
      if (!validateField(input) && !firstBad) firstBad = input;
    });

    if (firstBad) {
      firstBad.focus();
      firstBad.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'center' });
      return;
    }

    // 耗时判定（对应接口 ts 字段的反垃圾策略）：<3s 视为异常提交
    if (Date.now() - startedAt < 3000) {
      if (alertEl) {
        alertEl.hidden = false;
        alertEl.textContent = '提交过快，请稍候再试，或直接致电 0755-8888 0000。';
      }
      return;
    }

    submitBtn.disabled = true;
    submitBtn.innerHTML = '正在提交…';

    // 本地演示：无后端，模拟 POST /api/consult 的回执
    window.setTimeout(function () {
      var d = new Date();
      var pad = function (n) { return String(n).padStart(2, '0'); };
      var id =
        'ZS' +
        d.getFullYear() +
        pad(d.getMonth() + 1) +
        pad(d.getDate()) +
        'A' +
        pad(Math.floor(Math.random() * 99) + 1);

      if (receiptEl) receiptEl.textContent = id;
      form.hidden = true;
      if (successEl) {
        successEl.classList.add('is-on');
        successEl.focus();
        successEl.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'center' });
      }
    }, 900);
  });
})();
