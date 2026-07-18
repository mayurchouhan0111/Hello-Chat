/* APP.JS - DYNAMIC DATA BINDING AND EVENTS ORCHESTRATOR */

class PremiumRechargeEventApp {
  constructor() {
    this.configPath = './data/config.json';
    this.configData = null;
  }

  async init() {
    try {
      const response = await fetch(this.configPath);
      if (!response.ok) {
        throw new Error(`Failed to load config: ${response.statusText}`);
      }
      this.configData = await response.json();
      
      // Populate all components
      this.bindHeroDetails();
      this.bindEventDetails();
      this.bindPackagesTable();
      this.bindProgressTracker();
      this.bindFAQs();
      this.bindRules();
      this.bindStickyFooter();
      this.initializeCountdown();

    } catch (err) {
      console.error("Initialization error:", err);
      // Fallback: Bind basic elements with mock defaults if fetch fails
      this.bindMockDefaults();
    }

    // Scroll parallax event handler for background
    const simulatedFrame = document.querySelector('.app-viewport');
    const parallaxBg = document.querySelector('.parallax-bg');
    if (simulatedFrame && parallaxBg) {
      simulatedFrame.addEventListener('scroll', () => {
        const scrollTop = simulatedFrame.scrollTop;
        parallaxBg.style.transform = `translateY(${scrollTop * 0.25}px)`;
      });
    }
  }

  bindHeroDetails() {
    if (!this.configData) return;
    const titleEl = document.getElementById('event-title-node');
    if (titleEl) {
      // Split title into two lines if space exists
      const title = this.configData.title || "Recharge Bonus Event";
      const parts = title.split(' ');
      if (parts.length > 1) {
        const first = parts.slice(0, -2).join(' ') || parts[0];
        const last = parts.slice(-2).join(' ');
        titleEl.innerHTML = `${first} <span>${last}</span>`;
      } else {
        titleEl.textContent = title;
      }
    }
  }

  bindEventDetails() {
    if (!this.configData) return;
    const descEl = document.getElementById('details-text-node');
    if (descEl) descEl.textContent = this.configData.detailsText || '';
    
    const noteEl = document.getElementById('details-note-node');
    if (noteEl) noteEl.textContent = this.configData.detailsNote || '';
  }

  bindPackagesTable() {
    if (!this.configData || !this.configData.packages) return;
    
    const tableTextEl = document.getElementById('table-desc-text');
    if (tableTextEl) tableTextEl.textContent = this.configData.tableText || '';
    
    const tableNoteEl = document.getElementById('table-note-text');
    if (tableNoteEl) tableNoteEl.textContent = this.configData.tableNote || '';

    const tbody = document.getElementById('recharge-table-body');
    if (tbody) {
      tbody.innerHTML = '';
      this.configData.packages.forEach(pkg => {
        const row = document.createElement('tr');
        row.innerHTML = `
          <td class="text-val-usd">${pkg.rechargeAmount}</td>
          <td class="text-val-basic">${pkg.baseCoins}</td>
          <td class="text-val-bonus">${pkg.bonusCoins}</td>
          <td class="text-val-total">${pkg.totalCoins}</td>
        `;
        tbody.appendChild(row);
      });
    }
  }

  bindProgressTracker() {
    if (!this.configData || !this.configData.userProgress) return;
    new RechargeProgressTracker(this.configData.userProgress);
  }

  bindFAQs() {
    if (!this.configData || !this.configData.faqs) return;
    const container = document.getElementById('faq-accordion-container');
    if (container) {
      container.innerHTML = '';
      this.configData.faqs.forEach(faq => {
        const faqItem = document.createElement('div');
        faqItem.className = 'faq-item';
        faqItem.innerHTML = `
          <button class="faq-trigger">${faq.q}</button>
          <div class="faq-content">
            <p>${faq.a}</p>
          </div>
        `;
        
        // Accordion slide action
        const trigger = faqItem.querySelector('.faq-trigger');
        trigger.addEventListener('click', () => {
          const isActive = faqItem.classList.contains('active');
          // Close all other items
          container.querySelectorAll('.faq-item').forEach(item => {
            item.classList.remove('active');
            item.querySelector('.faq-content').style.maxHeight = null;
          });
          
          if (!isActive) {
            faqItem.classList.add('active');
            const content = faqItem.querySelector('.faq-content');
            content.style.maxHeight = content.scrollHeight + "px";
          }
        });

        container.appendChild(faqItem);
      });
    }
  }

  bindRules() {
    if (!this.configData || !this.configData.rules) return;
    const rulesList = document.getElementById('rules-list-container');
    if (rulesList) {
      rulesList.innerHTML = '';
      this.configData.rules.forEach(rule => {
        const li = document.createElement('li');
        li.textContent = rule;
        rulesList.appendChild(li);
      });
    }
  }

  bindStickyFooter() {
    if (!this.configData) return;
    const footerVal = document.getElementById('footer-ratio-val');
    if (footerVal) {
      footerVal.textContent = this.configData.subtitle || '1 $ = 3m coins';
    }
  }

  initializeCountdown() {
    if (!this.configData || !this.configData.endDate) return;
    new LiveCountdownTimer(this.configData.endDate);
  }

  bindMockDefaults() {
    console.warn("Loading fallback mock configuration data...");
    this.configData = {
      title: "Recharge Bonus Event",
      subtitle: "1 $ = 3m coins",
      endDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
      detailsText: "Welcome to the Recharge Bonus Event! Get 3 million coins instantly for every $1 you recharge. Event active for a limited time.",
      detailsNote: "Note: Rules subject to terms and conditions.",
      tableText: "Please refer to the exchange tiers below.",
      tableNote: "",
      packages: [
        { rechargeAmount: 1, baseCoins: "1,000,000", bonusCoins: "2,000,000", totalCoins: "3,000,000" },
        { rechargeAmount: 5, baseCoins: "5,000,000", bonusCoins: "10,000,000", totalCoins: "15,000,000" }
      ],
      userProgress: {
        currentRecharge: 0,
        milestones: [
          { threshold: 10, reward: "Reward 1", icon: "🏆" },
          { threshold: 50, reward: "Reward 2", icon: "🔥" }
        ]
      },
      faqs: [
        { q: "How does this event work?", a: "Simply recharge your wallet and bonuses will be credited automatically." }
      ],
      rules: [
        "Recharges during active window count towards bonus multipliers."
      ]
    };

    this.bindHeroDetails();
    this.bindEventDetails();
    this.bindPackagesTable();
    this.bindProgressTracker();
    this.bindFAQs();
    this.bindRules();
    this.bindStickyFooter();
    this.initializeCountdown();
  }
}

// Instantiate and start
const app = new PremiumRechargeEventApp();
window.addEventListener('DOMContentLoaded', () => app.init());

// Real-time integration hooks from Flutter WebView
window.setEventPackages = (packages) => {
  if (!packages || !Array.isArray(packages)) return;
  const mapped = packages.map(pkg => ({
    rechargeAmount: pkg.rechargeAmount,
    baseCoins: (pkg.baseCoins || 0).toLocaleString(),
    bonusCoins: (pkg.bonusCoins || 0).toLocaleString(),
    totalCoins: (pkg.totalCoins || 0).toLocaleString()
  }));
  if (app) {
    if (!app.configData) app.configData = {};
    app.configData.packages = mapped;
    app.bindPackagesTable();
  }
};

window.setUserData = (data) => {
  if (!data) return;
  if (app) {
    if (!app.configData) app.configData = {};
    if (!app.configData.userProgress) app.configData.userProgress = {};
    
    if (data.recharge !== undefined) {
      app.configData.userProgress.currentRecharge = parseFloat(data.recharge);
      app.bindProgressTracker();
    }
  }
};
