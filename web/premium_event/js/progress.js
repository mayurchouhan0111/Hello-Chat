/* PROGRESS.JS - VERTICAL ROADMAP MILESTONE PROGRESS TRACKER */

class RechargeProgressTracker {
  constructor(progressData) {
    this.currentRecharge = progressData.currentRecharge || 0;
    this.milestones = progressData.milestones || [];
    
    // Check URL parameters for dynamic override from Flutter WebView
    const urlParams = new URLSearchParams(window.location.search);
    const queryRecharge = urlParams.get('recharge');
    if (queryRecharge !== null) {
      const parsedVal = parseFloat(queryRecharge);
      if (!isNaN(parsedVal)) {
        this.currentRecharge = parsedVal;
      }
    }

    this.currentEl = document.getElementById('current-recharge-val');
    this.nextTargetEl = document.getElementById('next-target-val');
    this.lineFillEl = document.getElementById('vertical-line-fill');
    this.nodesContainerEl = document.getElementById('vertical-nodes-container');

    this.render();
  }

  render() {
    // 1. Sort milestones ascending by threshold
    this.milestones.sort((a, b) => a.threshold - b.threshold);
    const maxThreshold = this.milestones.length > 0 ? this.milestones[this.milestones.length - 1].threshold : 100;
    
    // 2. Find next target
    let nextTarget = maxThreshold;
    for (let m of this.milestones) {
      if (this.currentRecharge < m.threshold) {
        nextTarget = m.threshold;
        break;
      }
    }

    // 3. Update Text Info
    if (this.currentEl) this.currentEl.textContent = `${this.currentRecharge} $`;
    if (this.nextTargetEl) {
      if (this.currentRecharge >= maxThreshold) {
        this.nextTargetEl.textContent = "All milestones achieved!";
      } else {
        this.nextTargetEl.textContent = `Next milestone: ${nextTarget} $`;
      }
    }

    // 4. Render Nodes Vertically
    if (this.nodesContainerEl) {
      this.nodesContainerEl.innerHTML = '';
      
      this.milestones.forEach((m, idx) => {
        const isReached = this.currentRecharge >= m.threshold;
        const progressPercent = Math.min((this.currentRecharge / m.threshold) * 100, 100).toFixed(0);
        
        let statusText = "Locked";
        let statusClass = "locked";
        if (isReached) {
          statusText = "Claimed";
          statusClass = "claimed";
        } else if (idx === 0 || this.currentRecharge >= this.milestones[idx-1].threshold) {
          statusText = "In Progress";
          statusClass = "in-progress";
        }

        const nodeRow = document.createElement('div');
        nodeRow.className = `milestone-row ${isReached ? 'reached' : ''}`;
        
        nodeRow.innerHTML = `
          <!-- Left Col: Node Circle with Threshold -->
          <div class="milestone-node-col">
            <div class="milestone-circle">${m.threshold}$</div>
          </div>
          <!-- Center Col: Reward Details and Icon -->
          <div class="milestone-info-col">
            <span class="milestone-icon">${m.icon || '🎁'}</span>
            <div class="milestone-text-wrap">
              <div class="milestone-reward">${m.reward || ''}</div>
              <div class="milestone-sub">${isReached ? 'Reward claimed!' : `Progress: ${this.currentRecharge}/${m.threshold}$ (${progressPercent}%)`}</div>
            </div>
          </div>
          <!-- Right Col: Status Badge -->
          <div class="milestone-status-col">
            <span class="status-badge ${statusClass}">${statusText}</span>
          </div>
        `;
        
        this.nodesContainerEl.appendChild(nodeRow);
      });
    }

    // 5. Calculate Vertical Line Fill Height
    // Scale height linearly relative to milestone positions
    let fillPercent = 0;
    if (this.milestones.length > 0) {
      if (this.currentRecharge <= 0) {
        fillPercent = 0;
      } else if (this.currentRecharge >= maxThreshold) {
        fillPercent = 100;
      } else {
        // Find segment
        const numSegments = this.milestones.length - 1;
        const segmentWeight = 100 / numSegments;
        
        let activeSegment = 0;
        for (let i = 0; i < numSegments; i++) {
          if (this.currentRecharge >= this.milestones[i].threshold && this.currentRecharge <= this.milestones[i+1].threshold) {
            activeSegment = i;
            break;
          }
        }
        
        const segmentMin = this.milestones[activeSegment].threshold;
        const segmentMax = this.milestones[activeSegment+1].threshold;
        const segmentProgress = (this.currentRecharge - segmentMin) / (segmentMax - segmentMin);
        
        // We want the fill line to start from the center of the first circle and end at the center of the last circle.
        // There are N-1 segments between nodes. So we interpolate within those intervals.
        fillPercent = (activeSegment * segmentWeight) + (segmentProgress * segmentWeight);
      }
    }
    
    // Animate the vertical line height grow down
    setTimeout(() => {
      if (this.lineFillEl) {
        this.lineFillEl.style.height = `${Math.min(fillPercent, 100)}%`;
      }
    }, 150);
  }
}
