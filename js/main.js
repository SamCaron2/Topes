/* ── SHARED NAV BEHAVIOR ── */
document.addEventListener('DOMContentLoaded', () => {
  const header = document.getElementById('header');
  const onScroll = () => {
    if (header) header.classList.toggle('scrolled', window.scrollY > 60);
  };
  window.addEventListener('scroll', onScroll);
  onScroll();

  const hamburger = document.getElementById('hamburger');
  const mobileMenu = document.getElementById('mobileMenu');
  if (hamburger && mobileMenu) {
    hamburger.addEventListener('click', () => {
      mobileMenu.classList.toggle('open');
      hamburger.textContent = mobileMenu.classList.contains('open') ? '✕' : '☰';
    });
    mobileMenu.querySelectorAll('a').forEach(a => {
      a.addEventListener('click', () => {
        mobileMenu.classList.remove('open');
        hamburger.textContent = '☰';
      });
    });
  }

  // Highlight active nav link based on current page
  const path = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('nav.links a, .mobile-menu a').forEach(a => {
    const href = a.getAttribute('href');
    if (href === path || (path === '' && href === 'index.html')) {
      a.classList.add('active');
    }
  });
});

/* ── DATE HELPERS ── */
function fmtDate(iso) {
  const d = new Date(iso + 'T00:00:00');
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}
function isPast(iso) {
  const today = new Date(); today.setHours(0,0,0,0);
  return new Date(iso + 'T00:00:00') < today;
}

/* ── RECRUITING FORM ── */
function submitRec(event) {
  event.preventDefault();
  const name = document.getElementById('r-name').value.trim();
  const email = document.getElementById('r-email').value.trim();
  const status = document.getElementById('rec-status');
  status.style.display = 'block';
  if (!name || !email) {
    status.style.color = 'var(--red)';
    status.textContent = 'Please fill in your name and email.';
    return false;
  }
  status.style.color = 'var(--blue)';
  status.textContent = "Got it, " + name + ". We'll be in touch soon. #GoTopes";
  event.target.reset();
  return false;
}

/* ── SCHEDULE + EVENTS (schedule.html) ── */
function renderSchedulePage() {
  const tableBody = document.getElementById('scheduleBody');
  const cardsWrap = document.getElementById('scheduleCards');
  if (!tableBody) return;

  const games = SCHEDULE.map(g => ({ ...g, type: 'game', sortDate: g.date }));
  const events = EVENTS.map(e => ({ ...e, type: 'event', sortDate: e.date }));
  const combined = [...games, ...events].sort((a, b) => a.sortDate.localeCompare(b.sortDate));

  function resultBadge(item) {
    if (item.type === 'event') return `<span class="badge badge-event">Event</span>`;
    if (!item.result) return `<span class="badge badge-upcoming">Upcoming</span>`;
    return item.result.startsWith('W')
      ? `<span class="badge badge-result-w">${item.result}</span>`
      : `<span class="badge badge-result-l">${item.result}</span>`;
  }
  function homeAwayBadge(item) {
    if (item.type === 'event') return `<span class="badge badge-game" style="opacity:0.7;">Team Event</span>`;
    if (item.home === null) return `<span class="badge badge-upcoming">TBD</span>`;
    return item.home
      ? `<span class="badge badge-home">Home</span>`
      : `<span class="badge badge-away">Away</span>`;
  }

  function oppLogoImg(item) {
    if (item.type !== 'game' || !item.oppLogo) return '';
    return `<img src="${item.oppLogo}" alt="${item.opponent} logo" style="width:22px;height:22px;object-fit:contain;border-radius:3px;margin-right:8px;vertical-align:middle;">`;
  }

  function draw(filter) {
    const rows = combined.filter(item => filter === 'all' ? true : item.type === filter);

    if (rows.length === 0) {
      tableBody.innerHTML = `<tr><td colspan="6" style="padding:24px 16px;color:var(--muted);">No ${filter === 'event' ? 'events' : 'games'} on the calendar yet — check back soon.</td></tr>`;
      if (cardsWrap) cardsWrap.innerHTML = `<div class="event-card" style="color:var(--muted);">No ${filter === 'event' ? 'events' : 'games'} on the calendar yet — check back soon.</div>`;
      return;
    }

    tableBody.innerHTML = rows.map(item => {
      const title = item.type === 'game'
        ? `<span class="game-opponent">${oppLogoImg(item)}<span class="vs">${item.vs}</span>${item.opponent}</span>`
        : `<span class="game-opponent">${item.title}</span>`;
      return `<tr>
        <td><span class="game-date">${item.label}</span></td>
        <td>${title}</td>
        <td><span class="game-location">${item.location}</span></td>
        <td><span class="game-time">${item.time}</span></td>
        <td>${homeAwayBadge(item)}</td>
        <td>${resultBadge(item)}</td>
      </tr>`;
    }).join('');

    if (cardsWrap) {
      cardsWrap.innerHTML = rows.map(item => {
        const title = item.type === 'game' ? `${oppLogoImg(item)}${item.vs} ${item.opponent}` : item.title;
        return `<div class="event-card">
          <div class="row1"><span class="game-date">${item.label}</span>${resultBadge(item)}</div>
          <div class="opp">${title}</div>
          <div class="meta">${item.location} · ${item.time}</div>
          ${item.desc ? `<div class="meta" style="margin-top:6px;">${item.desc}</div>` : ''}
        </div>`;
      }).join('');
    }
  }

  draw('all');
  document.querySelectorAll('.tab-btn[data-filter]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn[data-filter]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      draw(btn.dataset.filter);
    });
  });
}

/* ── PAST SEASONS (schedule.html) ── */
function renderSeasonHistory() {
  const tableBody = document.getElementById('seasonHistoryBody');
  const recordEl = document.getElementById('seasonRecord');
  if (!tableBody) return;

  function oppLogoImg(item) {
    if (!item.oppLogo) return '';
    return `<img src="${item.oppLogo}" alt="${item.opponent} logo" style="width:22px;height:22px;object-fit:contain;border-radius:3px;margin-right:8px;vertical-align:middle;">`;
  }

  function draw(year) {
    const games = SEASON_HISTORY[year] || [];
    const wins = games.filter(g => g.result && g.result.startsWith('W')).length;
    const losses = games.filter(g => g.result && g.result.startsWith('L')).length;
    if (recordEl) recordEl.textContent = `${year} Season Record: ${wins}–${losses}`;

    tableBody.innerHTML = games.map(item => `
      <tr>
        <td><span class="game-date">${item.label}</span></td>
        <td><span class="game-opponent">${oppLogoImg(item)}<span class="vs">${item.vs}</span>${item.opponent}</span></td>
        <td><span class="game-location">${item.location}</span></td>
        <td><span class="game-time">${item.time}</span></td>
        <td>${item.home ? '<span class="badge badge-home">Home</span>' : '<span class="badge badge-away">Away</span>'}</td>
        <td>${item.result.startsWith('W') ? `<span class="badge badge-result-w">${item.result}</span>` : `<span class="badge badge-result-l">${item.result}</span>`}</td>
      </tr>
    `).join('');
  }

  draw('2025');
  document.querySelectorAll('.tab-btn[data-year]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn[data-year]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      draw(btn.dataset.year);
    });
  });
}

/* ── ROSTER GRID (roster.html) ── */
function renderRoster() {
  const grid = document.getElementById('rosterGrid');
  if (!grid) return;

  function placeholderPhoto(p) {
    if (p.photo) return `<img src="${p.photo}" alt="${p.name}">`;
    return `<div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:linear-gradient(160deg,var(--mid),var(--dark));">
      <span style="font-family:'Barlow Condensed',sans-serif;font-weight:900;font-size:3.6rem;color:var(--border);">${p.number}</span>
    </div>`;
  }

  function draw(filter) {
    const players = ROSTER
      .filter(p => filter === 'All' ? true : p.position === filter)
      .slice()
      .sort((a, b) => a.number - b.number);
    grid.innerHTML = players.map(p => `
      <a class="player-card" href="player.html?id=${p.id}">
        <div class="photo">
          ${placeholderPhoto(p)}
          <span class="num">#${p.number}</span>
        </div>
        <div class="info">
          <div class="pos">${p.position}</div>
          <h3>${p.name}</h3>
          <div class="hometown">${p.hometown}</div>
        </div>
      </a>
    `).join('');
  }

  draw('All');
  document.querySelectorAll('.tab-btn[data-pos]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn[data-pos]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      draw(btn.dataset.pos);
    });
  });
}

/* ── STAFF (roster.html) ── */
function renderStaff() {
  const grid = document.getElementById('staffGrid');
  if (!grid) return;
  function initials(name) {
    return name.split(' ').map(w => w[0]).join('').toUpperCase();
  }
  grid.innerHTML = STAFF.map(s => `
    <div class="staff-card">
      <div class="avatar">${initials(s.name)}</div>
      <h4>${s.name}</h4>
      <div class="role">${s.role}</div>
    </div>
  `).join('');
}

/* ── PLAYER DETAIL (player.html) ── */
function renderPlayerDetail() {
  const wrap = document.getElementById('playerDetail');
  if (!wrap) return;
  const params = new URLSearchParams(window.location.search);
  const id = parseInt(params.get('id'), 10);
  const p = ROSTER.find(pl => pl.id === id);

  if (!p) {
    wrap.innerHTML = `<div style="padding:60px 0;text-align:center;">
      <p class="label">Player Not Found</p>
      <h2 class="display" style="color:var(--white);margin:14px 0 24px;font-size:2.2rem;">We couldn't find that roster entry.</h2>
      <a href="roster.html" class="btn btn-blue">Back to Roster</a>
    </div>`;
    document.title = "Player Not Found | Inver Grove Isotopes";
    return;
  }

  document.title = `${p.name} | #${p.number} | Inver Grove Isotopes`;

  const photoHtml = p.photo
    ? `<img src="${p.photo}" alt="${p.name}">`
    : `<div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:linear-gradient(160deg,var(--mid),var(--dark));">
        <span style="font-family:'Barlow Condensed',sans-serif;font-weight:900;font-size:6rem;color:var(--border);">${p.number}</span>
      </div>`;

  wrap.innerHTML = `
    <a href="roster.html" class="back-link">&larr; Back to Roster</a>
    <div class="player-detail-grid">
      <div class="player-photo-wrap">${photoHtml}</div>
      <div>
        <p class="label">${p.position}</p>
        <div class="player-header">
          <span class="jersey">#${p.number}</span>
          <h1 class="display">${p.name}</h1>
        </div>
        <div class="player-meta-row">
          <div class="m-item"><span class="k">Hometown</span><span class="v">${p.hometown}</span></div>
          <div class="m-item"><span class="k">Height</span><span class="v">${p.height}</span></div>
          <div class="m-item"><span class="k">Weight</span><span class="v">${p.weight} lbs</span></div>
        </div>
        <p style="color:var(--muted);font-size:0.9rem;">Bio and season stats coming soon.</p>
      </div>
    </div>
  `;
}

/* ── JUNIORS SCHEDULE (juniors.html) ── */
function renderJuniorsSchedule() {
  const tableBody = document.getElementById('juniorsScheduleBody');
  if (!tableBody) return;
  const typeBadge = (type) => type === 'Game'
    ? `<span class="badge badge-game">${type}</span>`
    : `<span class="badge badge-event">${type}</span>`;
  tableBody.innerHTML = JUNIORS_SCHEDULE.map(g => `
    <tr>
      <td><span class="game-date">${g.label}</span></td>
      <td><span class="game-opponent">${g.title}</span></td>
      <td>${typeBadge(g.type)}</td>
      <td><span class="game-location">${g.location}</span></td>
      <td><span class="game-time">${g.time}</span></td>
    </tr>
  `).join('');
}
function renderJuniorsLocations() {
  const wrap = document.getElementById('juniorsLocations');
  if (!wrap) return;
  wrap.innerHTML = JUNIORS_LOCATIONS.map(l => `
    <div class="location-card">
      <span class="tag">${l.tag}</span>
      <h4 style="margin-top:12px;">${l.name}</h4>
      <p class="addr">${l.address}</p>
      <p class="addr">${l.note}</p>
    </div>
  `).join('');
}

/* ── GALLERY (gallery.html) ── */
let galleryFiltered = [];
function renderGallery() {
  const grid = document.getElementById('galleryGrid');
  if (!grid) return;

  function draw(filter) {
    galleryFiltered = GALLERY.filter(g => filter === 'all' ? true : g.category === filter);
    grid.innerHTML = galleryFiltered.map((g, i) => `
      <div class="gallery-item${i % 5 === 0 ? ' wide' : ''}" onclick="openLightbox(${i})">
        <img src="${g.src}" alt="${g.caption}" loading="lazy">
      </div>
    `).join('');
  }

  draw('all');
  document.querySelectorAll('.tab-btn[data-cat]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn[data-cat]').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      draw(btn.dataset.cat);
    });
  });
}

let lightboxIndex = 0;
function openLightbox(i) {
  lightboxIndex = i;
  updateLightbox();
  document.getElementById('lightbox').classList.add('open');
}
function closeLightbox() {
  document.getElementById('lightbox').classList.remove('open');
}
function updateLightbox() {
  const item = galleryFiltered[lightboxIndex];
  if (!item) return;
  document.getElementById('lightboxImg').src = item.src;
  document.getElementById('lightboxImg').alt = item.caption;
  document.getElementById('lightboxCap').textContent = item.caption;
}
function lightboxNext(dir) {
  lightboxIndex = (lightboxIndex + dir + galleryFiltered.length) % galleryFiltered.length;
  updateLightbox();
}
document.addEventListener('keydown', (e) => {
  const lb = document.getElementById('lightbox');
  if (!lb || !lb.classList.contains('open')) return;
  if (e.key === 'Escape') closeLightbox();
  if (e.key === 'ArrowRight') lightboxNext(1);
  if (e.key === 'ArrowLeft') lightboxNext(-1);
});
