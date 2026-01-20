// ===============================
// Counter Configuration
// ===============================
const CONFIG = {
    apiBase: 'https://api.counterapi.dev/v1',
    namespace: 'lock_n_key_v1',
    token: 'ut_Lumh3piycqTZFKjBCOBfB2oJJa05qTI9Sty2CfXS', // verified token
    keys: {
        likes: 'likes_count',
        downloads: 'downloads_count'
    },
    localKeys: {
        hasLiked: 'lock_n_key_user_has_liked'
    }
};

// ===============================
// Counter Manager
// ===============================
class CounterManager {
    constructor() {
        this.downloadCountElement = document.getElementById('downloadCount');
        this.likeCountElement = document.getElementById('likeCount');
        this.likeBtn = document.getElementById('likeBtn');
        this.heartIcon = document.querySelector('.heart-icon');

        this.downloads = 0;
        this.likes = 0;

        this.init();
    }

    // -------------------------------
    // Init
    // -------------------------------
    init() {
        this.loadCounts();          // load once
        this.restoreLikeState();    // restore local like
        this.attachEventListeners();
    }

    // -------------------------------
    // Fetch helper
    // -------------------------------
    async fetchCount(endpoint) {
        try {
            const url = `${CONFIG.apiBase}/${CONFIG.namespace}/${endpoint}?token=${CONFIG.token}`;
            const res = await fetch(url);

            if (!res.ok) throw new Error(`HTTP ${res.status}`);

            const data = await res.json();
            return typeof data.count === 'number' ? data.count : null;
        } catch (err) {
            console.error('CounterAPI error:', err);
            return null;
        }
    }

    // -------------------------------
    // Initial load
    // -------------------------------
    async loadCounts() {
        const downloads = await this.fetchCount(CONFIG.keys.downloads);
        const likes = await this.fetchCount(CONFIG.keys.likes);

        if (downloads !== null) {
            this.downloads = downloads;
            this.updateDisplay(this.downloadCountElement, downloads);
        }

        if (likes !== null) {
            this.likes = likes;
            this.updateDisplay(this.likeCountElement, likes);
        }
    }

    // -------------------------------
    // Display helper
    // -------------------------------
    updateDisplay(el, value) {
        if (!el) return;
        el.innerText = value.toLocaleString();
    }

    // -------------------------------
    // Like state
    // -------------------------------
    restoreLikeState() {
        const hasLiked = localStorage.getItem(CONFIG.localKeys.hasLiked) === 'true';
        if (hasLiked) this.setLikedUI(true);
    }

    setLikedUI(active) {
        if (!this.likeBtn || !this.heartIcon) return;

        if (active) {
            this.likeBtn.classList.add('liked');
            this.heartIcon.setAttribute('fill', 'currentColor');
        } else {
            this.likeBtn.classList.remove('liked');
            this.heartIcon.setAttribute('fill', 'none');
        }
    }

    // -------------------------------
    // Increment download
    // -------------------------------
    async incrementDownloads() {
        const newVal = await this.fetchCount(`${CONFIG.keys.downloads}/up`);
        if (newVal !== null) {
            this.downloads = newVal;
            this.updateDisplay(this.downloadCountElement, newVal);
        }
    }

    // -------------------------------
    // Toggle like
    // -------------------------------
    async toggleLike() {
        const hasLiked = localStorage.getItem(CONFIG.localKeys.hasLiked) === 'true';

        if (hasLiked) {
            // UNLIKE
            localStorage.setItem(CONFIG.localKeys.hasLiked, 'false');
            this.setLikedUI(false);

            const newVal = await this.fetchCount(`${CONFIG.keys.likes}/down`);
            if (newVal !== null) {
                this.likes = newVal;
                this.updateDisplay(this.likeCountElement, newVal);
            }
        } else {
            // LIKE
            localStorage.setItem(CONFIG.localKeys.hasLiked, 'true');
            this.setLikedUI(true);
            this.animateLike();

            const newVal = await this.fetchCount(`${CONFIG.keys.likes}/up`);
            if (newVal !== null) {
                this.likes = newVal;
                this.updateDisplay(this.likeCountElement, newVal);
            }
        }
    }

    // -------------------------------
    // Like animation
    // -------------------------------
    animateLike() {
        this.likeBtn.style.transform = 'scale(1.2)';
        setTimeout(() => {
            this.likeBtn.style.transform = 'scale(1)';
        }, 200);
    }

    // -------------------------------
    // Events
    // -------------------------------
    attachEventListeners() {
        if (this.likeBtn) {
            this.likeBtn.addEventListener('click', () => this.toggleLike());
        }

        const downloadBtn = document.getElementById('downloadBtn');
        if (downloadBtn) {
            downloadBtn.addEventListener('click', () => this.incrementDownloads());
        }
    }
}

// ===============================
// Boot
// ===============================
document.addEventListener('DOMContentLoaded', () => {
    AOS.init({
        duration: 800,
        once: true,
        offset: 100
    });

    new CounterManager();
});
