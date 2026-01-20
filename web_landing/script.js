
// Counter Configuration
const CONFIG = {
    // API Endpoint (V1 for token support)
    apiBase: 'https://api.counterapi.dev/v1',
    namespace: 'lock_n_key_v1',
    token: 'ut_Lumh3piycqTZFKjBCOBfB2oJJa05qTI9Sty2CfXS', // Verified token
    keys: {
        likes: 'likes_count',
        downloads: 'downloads_count'
    },
    // Local storage keys (only for tracking user status, not counts)
    localKeys: {
        hasLiked: 'lock_n_key_user_has_liked'
    }
};

class CounterManager {
    constructor() {
        this.downloadCountElement = document.getElementById('downloadCount');
        this.likeCountElement = document.getElementById('likeCount');
        this.likeBtn = document.getElementById('likeBtn');
        this.heartIcon = document.querySelector('.heart-icon');

        this.init();
    }

    init() {
        this.loadCounts();
        this.checkLikedStatus();
        this.attachEventListeners();
    }

    // Helper to fetch data safely
    async fetchData(endpoint) {
        try {
            // Construct URL with token
            const url = `${CONFIG.apiBase}/${CONFIG.namespace}/${endpoint}?token=${CONFIG.token}`;
            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            return data.count; // CounterAPI.dev returns { "count": 123, ... }
        } catch (error) {
            console.error('Error fetching counter:', error);
            return null;
        }
    }

    async loadCounts() {
        // Fetch Downloads
        const downloads = await this.fetchData(`${CONFIG.keys.downloads}`);
        if (downloads !== null) {
            this.downloads = downloads;
            this.updateDisplay(this.downloadCountElement, this.downloads);
        } else {
            // Fallback
            this.updateDisplay(this.downloadCountElement, '1,200+');
        }

        // Fetch Likes
        const likes = await this.fetchData(`${CONFIG.keys.likes}`);
        if (likes !== null) {
            this.likes = likes;
            this.updateDisplay(this.likeCountElement, this.likes);
        } else {
            this.updateDisplay(this.likeCountElement, '500+');
        }
    }

    updateDisplay(element, value) {
        if (!element) return;
        if (typeof value === 'number') {
            element.innerText = value.toLocaleString();
        } else {
            element.innerText = value;
        }
    }

    checkLikedStatus() {
        const hasLiked = localStorage.getItem(CONFIG.localKeys.hasLiked) === 'true';
        if (hasLiked) {
            this.setLikedState();
        }
    }

    setLikedState() {
        this.likeBtn.classList.add('liked');
        if (this.heartIcon) {
            this.heartIcon.setAttribute('fill', 'currentColor');
        }
    }

    async incrementDownloads() {
        // Optimistic update
        if (typeof this.downloads === 'number') {
            this.downloads++;
            this.updateDisplay(this.downloadCountElement, this.downloads);
        }

        // Hit API (up)
        const newVal = await this.fetchData(`${CONFIG.keys.downloads}/up`);
        if (newVal !== null) {
            this.downloads = newVal;
            this.updateDisplay(this.downloadCountElement, this.downloads);
        }
    }

    async toggleLike() {
        const hasLiked = localStorage.getItem(CONFIG.localKeys.hasLiked) === 'true';

        if (hasLiked) {
            // Unlike functionality
            this.likeBtn.classList.remove('liked');
            if (this.heartIcon) this.heartIcon.setAttribute('fill', 'none');
            localStorage.setItem(CONFIG.localKeys.hasLiked, 'false');

            // Optimistic update
            if (typeof this.likes === 'number') {
                this.likes--;
                this.updateDisplay(this.likeCountElement, this.likes);
            }

            // Sync with Server (Down)
            const newVal = await this.fetchData(`${CONFIG.keys.likes}/down`);
            if (newVal !== null) {
                this.likes = newVal;
                this.updateDisplay(this.likeCountElement, this.likes);
            }

        } else {
            // Like functionality
            this.setLikedState();
            this.animateLike();
            localStorage.setItem(CONFIG.localKeys.hasLiked, 'true');

            // Optimistic update
            if (typeof this.likes === 'number') {
                this.likes++;
                this.updateDisplay(this.likeCountElement, this.likes);
            }

            // Sync with Server (Up)
            const newVal = await this.fetchData(`${CONFIG.keys.likes}/up`);
            if (newVal !== null) {
                this.likes = newVal;
                this.updateDisplay(this.likeCountElement, this.likes);
            }
        }
    }

    animateLike() {
        this.likeBtn.style.transform = 'scale(1.2)';
        setTimeout(() => {
            this.likeBtn.style.transform = 'scale(1)';
        }, 200);
    }

    attachEventListeners() {
        if (this.likeBtn) {
            this.likeBtn.addEventListener('click', () => this.toggleLike());
        }

        const downloadBtn = document.getElementById('downloadBtn');
        if (downloadBtn) {
            downloadBtn.addEventListener('click', () => {
                this.incrementDownloads();
            });
        }
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Initialize AOS
    AOS.init({
        duration: 800,
        once: true,
        offset: 100
    });

    // Initialize Counters
    new CounterManager();
});
