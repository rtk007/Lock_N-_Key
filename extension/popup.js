document.addEventListener('DOMContentLoaded', () => {
    // Load pending secret
    chrome.storage.local.get(['pendingSecret'], (result) => {
        if (result.pendingSecret) {
            document.getElementById('value').value = result.pendingSecret;
            // Clear it so it doesn't persist
            chrome.storage.local.remove(['pendingSecret']);
        }
    });

    document.getElementById('saveBtn').addEventListener('click', async () => {
        const name = document.getElementById('name').value;
        const value = document.getElementById('value').value;
        const type = document.getElementById('type').value;
        const shortcut = document.getElementById('shortcut').value;
        const tagsRaw = document.getElementById('tags').value;

        if (!name || !value) {
            showStatus('Name and Value are required', false);
            return;
        }

        const tags = tagsRaw.split(',').map(t => t.trim()).filter(t => t);

        const payload = { name, value, type, shortcut, tags };

        setLoading(true);

        try {
            const response = await fetch('http://127.0.0.1:45454/secrets/add', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            if (response.ok) {
                showStatus('Saved Successfully!', true);
                setTimeout(() => window.close(), 1500);
            } else {
                const text = await response.text();
                showStatus('Failed: ' + text, false);
                setLoading(false);
            }
        } catch (e) {
            showStatus('Error: Is Lock N Key running?', false);
            setLoading(false);
        }
    });
});

function showStatus(msg, isSuccess) {
    const el = document.getElementById('status');
    el.textContent = msg;
    el.className = isSuccess ? 'success' : 'error';
}

function setLoading(isLoading) {
    const btn = document.getElementById('saveBtn');
    btn.disabled = isLoading;
    btn.textContent = isLoading ? 'Saving...' : 'Save to Vault';
}
