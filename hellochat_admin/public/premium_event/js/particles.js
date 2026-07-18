/* PARTICLES.JS - LIGHTWEIGHT CANVAS FLOATING COINS PHYSICS */

class CoinParticleSystem {
  constructor(canvasId) {
    this.canvas = document.getElementById(canvasId);
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');
    this.particles = [];
    this.maxParticles = 20;
    this.animationFrameId = null;

    this.resizeCanvas();
    window.addEventListener('resize', () => this.resizeCanvas());

    this.init();
    this.animate();
  }

  resizeCanvas() {
    const parent = this.canvas.parentElement;
    this.canvas.width = parent.clientWidth;
    this.canvas.height = parent.clientHeight;
  }

  init() {
    for (let i = 0; i < this.maxParticles; i++) {
      this.particles.push(this.createParticle(true));
    }
  }

  createParticle(randomY = false) {
    const w = this.canvas.width;
    const h = this.canvas.height;

    return {
      x: Math.random() * w,
      y: randomY ? Math.random() * h : h + 20,
      size: 5 + Math.random() * 8, // coin radius
      speedY: 0.6 + Math.random() * 0.8, // upward velocity
      speedX: -0.3 + Math.random() * 0.6, // horizontal drift
      angle: Math.random() * Math.PI * 2,
      spinSpeed: 0.02 + Math.random() * 0.05,
      scaleX: Math.random(),
      scaleSpeed: 0.03 + Math.random() * 0.04,
      alpha: randomY ? Math.random() * 0.8 : 0,
      fadeInSpeed: 0.02,
      fadeOutThreshold: h * 0.2 // starts fading out in the top 20% of the banner
    };
  }

  animate() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    const h = this.canvas.height;

    for (let i = 0; i < this.particles.length; i++) {
      let p = this.particles[i];

      // Update positions
      p.y -= p.speedY;
      p.x += p.speedX;
      p.angle += p.spinSpeed;
      
      // Update 3D spin simulation
      p.scaleX += p.scaleSpeed;
      if (p.scaleX > 1 || p.scaleX < -1) {
        p.scaleSpeed = -p.scaleSpeed;
      }

      // Handle Fade In / Out
      if (p.y > h - 50) {
        if (p.alpha < 0.8) p.alpha += p.fadeInSpeed;
      } else if (p.y < p.fadeOutThreshold) {
        p.alpha -= 0.015;
      }

      // Recycle dead particles
      if (p.y < -20 || p.alpha <= 0 || p.x < -20 || p.x > this.canvas.width + 20) {
        this.particles[i] = this.createParticle(false);
        continue;
      }

      // DRAW GOLD COIN
      this.ctx.save();
      this.ctx.translate(p.x, p.y);
      this.ctx.rotate(p.angle);
      this.ctx.scale(p.scaleX, 1); // simulate spinning coin

      // Outer gold rim
      this.ctx.beginPath();
      this.ctx.arc(0, 0, p.size, 0, Math.PI * 2);
      let grad = this.ctx.createRadialGradient(0, 0, p.size * 0.1, 0, 0, p.size);
      grad.addColorStop(0, '#fff6bd');
      grad.addColorStop(0.3, '#ffd700');
      grad.addColorStop(0.8, '#b8860b');
      grad.addColorStop(1, '#6b4c03');
      this.ctx.fillStyle = grad;
      this.ctx.globalAlpha = p.alpha;
      this.ctx.fill();

      // Inner details (rim line)
      this.ctx.beginPath();
      this.ctx.arc(0, 0, p.size * 0.7, 0, Math.PI * 2);
      this.ctx.strokeStyle = '#b8860b';
      this.ctx.lineWidth = p.size * 0.08;
      this.ctx.globalAlpha = p.alpha;
      this.ctx.stroke();

      // Central gold star/diamond
      this.ctx.beginPath();
      this.ctx.moveTo(0, -p.size * 0.4);
      this.ctx.lineTo(p.size * 0.3, 0);
      this.ctx.lineTo(0, p.size * 0.4);
      this.ctx.lineTo(-p.size * 0.3, 0);
      this.ctx.closePath();
      this.ctx.fillStyle = '#fff6bd';
      this.ctx.globalAlpha = p.alpha;
      this.ctx.fill();

      this.ctx.restore();
    }

    this.animationFrameId = requestAnimationFrame(() => this.animate());
  }

  stop() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }
  }
}

// Initialize on page load
window.addEventListener('load', () => {
  new CoinParticleSystem('particle-canvas');
});
