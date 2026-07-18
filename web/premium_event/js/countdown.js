/* COUNTDOWN.JS - LIVE TICKING EVENT TIMER */

class LiveCountdownTimer {
  constructor(endDateString) {
    this.targetDate = new Date(endDateString);
    if (isNaN(this.targetDate.getTime())) {
      // Default fallback: 3 days from now
      this.targetDate = new Date();
      this.targetDate.setDate(this.targetDate.getDate() + 3);
    }
    
    this.daysEl = document.getElementById('timer-days');
    this.hoursEl = document.getElementById('timer-hours');
    this.minsEl = document.getElementById('timer-mins');
    this.secsEl = document.getElementById('timer-secs');
    
    this.timerInterval = null;
    this.start();
  }

  start() {
    this.update();
    this.timerInterval = setInterval(() => this.update(), 1000);
  }

  update() {
    const now = new Date().getTime();
    const diff = this.targetDate.getTime() - now;

    if (diff <= 0) {
      this.handleExpiry();
      return;
    }

    // Time calculations
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const mins = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    const secs = Math.floor((diff % (1000 * 60)) / 1000);

    // Render with padding
    if (this.daysEl) this.daysEl.textContent = String(days).padStart(2, '0');
    if (this.hoursEl) this.hoursEl.textContent = String(hours).padStart(2, '0');
    if (this.minsEl) this.minsEl.textContent = String(mins).padStart(2, '0');
    if (this.secsEl) this.secsEl.textContent = String(secs).padStart(2, '0');
  }

  handleExpiry() {
    clearInterval(this.timerInterval);
    if (this.daysEl) this.daysEl.textContent = '00';
    if (this.hoursEl) this.hoursEl.textContent = '00';
    if (this.minsEl) this.minsEl.textContent = '00';
    if (this.secsEl) this.secsEl.textContent = '00';
    
    const labelEl = document.querySelector('.countdown-label');
    if (labelEl) labelEl.textContent = 'Event Completed';
  }

  stop() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
    }
  }
}
