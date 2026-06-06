const header = document.querySelector('.site-header');
const menuToggle = document.querySelector('.menu-toggle');
const navLinks = document.querySelectorAll('.site-nav a, .header-actions a');
const reserveForm = document.querySelector('#reserve-form');
const reserveCopy = document.querySelector('#reserve-copy');
const reserveNote = document.querySelector('#reserve-note');
const reserveSubmit = document.querySelector('#reserve-submit');

const defaultReserveNote = reserveNote?.textContent?.trim() || '';
const reserveMessages = {
  submitting: '正在提交到私有候补名单，请稍候。',
  success: '已进入私有候补名单。开放 Pro 或支付通道时，我们会按登记邮箱联系你。',
  error: '提交未完成，请稍后重试；如果当前环境尚未配置私有通道，你可以先复制登记内容备用。',
  copied: '登记内容已复制。即使当前私有通道暂未配置，你也可以先保存这份登记信息。',
  copyFailed: '浏览器未允许剪贴板写入，请手动复制或稍后重试。',
};

function buildReservePayload(form) {
  const formData = new FormData(form);

  return {
    role: String(formData.get('role') || '').trim(),
    volume: String(formData.get('volume') || '').trim(),
    contact: String(formData.get('contact') || '').trim(),
    problem: String(formData.get('problem') || '').trim(),
    price: String(formData.get('price') || '').trim(),
    website: String(formData.get('website') || '').trim(),
  };
}

function buildReserveDraft(form) {
  const payload = buildReservePayload(form);

  return {
    title: `[Pro 候补] ${payload.role || '未填写'} / ${payload.volume || '未填写'}`,
    body: [
      '## Pro 私有候补登记',
      '',
      `- 角色：${payload.role || '未填写'}`,
      `- 每周下载频率：${payload.volume || '未填写'}`,
      `- 联系邮箱：${payload.contact || '未填写'}`,
      `- 可接受价格区间：${payload.price || '未填写'}`,
      '',
      '## 最想优先解决的问题',
      '',
      payload.problem || '未填写',
    ].join('\n'),
  };
}

function setReserveNote(state, message) {
  if (!reserveNote) {
    return;
  }

  reserveNote.dataset.state = state;
  reserveNote.textContent = message;
}

function resetReserveNote() {
  if (!reserveNote) {
    return;
  }

  delete reserveNote.dataset.state;
  reserveNote.textContent = defaultReserveNote;
}

function setSubmitPending(isPending) {
  if (!(reserveSubmit instanceof HTMLButtonElement)) {
    return;
  }

  reserveSubmit.disabled = isPending;
  reserveSubmit.textContent = isPending ? '正在提交...' : '提交私有候补登记';
}

async function readWaitlistError(response) {
  try {
    const payload = await response.json();
    if (payload && typeof payload.error === 'string' && payload.error.trim()) {
      return payload.error.trim();
    }
  } catch {
    return reserveMessages.error;
  }

  return reserveMessages.error;
}

if (menuToggle && header) {
  menuToggle.addEventListener('click', () => {
    const isOpen = header.classList.toggle('nav-open');
    menuToggle.setAttribute('aria-expanded', String(isOpen));
  });

  navLinks.forEach((link) => {
    link.addEventListener('click', () => {
      header.classList.remove('nav-open');
      menuToggle.setAttribute('aria-expanded', 'false');
    });
  });
}

if (reserveForm instanceof HTMLFormElement) {
  reserveForm.addEventListener('submit', async (event) => {
    event.preventDefault();

    const payload = buildReservePayload(reserveForm);
    setSubmitPending(true);
    setReserveNote('submitting', reserveMessages.submitting);

    try {
      const response = await fetch('/api/waitlist', {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        throw new Error(await readWaitlistError(response));
      }

      setReserveNote('success', reserveMessages.success);
    } catch (error) {
      const message = error instanceof Error && error.message ? error.message : reserveMessages.error;
      setReserveNote('error', message);
    } finally {
      setSubmitPending(false);
    }
  });
}

if (reserveForm instanceof HTMLFormElement && reserveCopy instanceof HTMLButtonElement) {
  reserveCopy.addEventListener('click', async () => {
    const draft = buildReserveDraft(reserveForm);
    const text = `${draft.title}\n\n${draft.body}`;

    try {
      await navigator.clipboard.writeText(text);
      reserveCopy.textContent = '已复制登记内容';
      setReserveNote('success', reserveMessages.copied);
      window.setTimeout(() => {
        reserveCopy.textContent = '复制登记内容';
      }, 2200);
    } catch {
      setReserveNote('error', reserveMessages.copyFailed);
    }
  });

  reserveForm.addEventListener('reset', () => {
    window.setTimeout(() => {
      resetReserveNote();
      setSubmitPending(false);
    }, 0);
  });
}
