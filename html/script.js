(function () {
    'use strict';
    const overlay = document.getElementById('document-overlay');
    const stamp = document.getElementById('stamp');
    const stampText = document.getElementById('stamp-text');
    const docTypeText = document.getElementById('doc-type-text');
    const docStatusText = document.getElementById('doc-status-text');
    const objPanel = document.getElementById('objectives-panel');
    const objList = document.getElementById('objectives-list');
    let isDocOpen = false;
    let objectives = {};
    const OBJ_DEFS = {
        go_farm: { icon: 'fa-truck', text: 'Go to the farm' },
        load_crates: { icon: 'fa-box', text: 'Load the crates' },
        get_document: { icon: 'fa-file-lines', text: 'Get certificate' },
        deliver: { icon: 'fa-dolly', text: 'Deliver' },
    };
    window.addEventListener('message', function (event) {
        const data = event.data;
        switch (data.action) {
            case 'showDocument':
                showDocument(data.type, data.autoClose || false);
                break;
            case 'showCertificate':
                showCertificate(data.type);
                break;
            case 'hideDocument':
                closeDocument();
                break;
            case 'showObjectives':
                showObjectives(data.objectives);
                break;
            case 'hideObjectives':
                hideObjectives();
                break;
            case 'updateObjective':
                updateObjective(data.key, data.completed, data.counter, data.total);
                break;
        }
    });
    function showObjectives(objData) {
        objectives = {};
        objList.innerHTML = '';
        const items = objData || [
            { key: 'go_farm' },
            { key: 'load_crates' },
            { key: 'get_document' },
            { key: 'deliver' },
        ];
        items.forEach(function (item) {
            const def = OBJ_DEFS[item.key] || {};
            const icon = item.icon || def.icon || 'fa-circle';
            const text = item.text || def.text || item.key;
            objectives[item.key] = {
                completed: item.completed || false,
                counter: item.counter || 0,
                total: item.total || 0,
            };
            const el = document.createElement('div');
            el.className = 'obj-item' + (item.completed ? ' completed' : '');
            el.id = 'obj-' + item.key;
            let counterHtml = '';
            if (item.total && item.total > 0) {
                counterHtml = '<span class="obj-counter">' + (item.counter || 0) + '/' + item.total + '</span>';
            }
            el.innerHTML =
                '<i class="obj-icon fas ' + icon + '"></i>' +
                '<span class="obj-text">' + text + '</span>' +
                counterHtml +
                '<i class="obj-check fas fa-check"></i>';
            objList.appendChild(el);
        });
        objPanel.classList.remove('hidden');
    }
    function updateObjective(key, completed, counter, total) {
        if (!objectives[key]) return;
        const el = document.getElementById('obj-' + key);
        if (!el) return;
        if (completed !== undefined) {
            objectives[key].completed = completed;
            if (completed) {
                el.classList.add('completed');
            } else {
                el.classList.remove('completed');
            }
        }
        if (counter !== undefined || total !== undefined) {
            if (counter !== undefined) objectives[key].counter = counter;
            if (total !== undefined) objectives[key].total = total;
            const counterEl = el.querySelector('.obj-counter');
            if (counterEl) {
                counterEl.textContent = objectives[key].counter + '/' + objectives[key].total;
            } else if (objectives[key].total > 0) {
                const span = document.createElement('span');
                span.className = 'obj-counter';
                span.textContent = objectives[key].counter + '/' + objectives[key].total;
                const check = el.querySelector('.obj-check');
                el.insertBefore(span, check);
            }
        }
    }
    function hideObjectives() {
        objPanel.classList.add('hidden');
        objectives = {};
        objList.innerHTML = '';
    }
    let autoCloseTimer = null;
    function showDocument(type, autoClose) {
        stamp.className = 'stamp';
        stamp.classList.add(type);
        stamp.classList.remove('stamp-hidden');
        if (type === 'green') {
            stampText.textContent = 'APPROVED';
            docTypeText.textContent = 'Legal Transport Document';
            docTypeText.style.color = '#228B22';
            docStatusText.textContent = 'Risk-Free - Approved';
            docStatusText.style.color = '#228B22';
        } else {
            stampText.textContent = 'SMUGGLED';
            docTypeText.textContent = 'Unregistered Document';
            docTypeText.style.color = '#C81E1E';
            docStatusText.textContent = 'Risky - Unregistered';
            docStatusText.style.color = '#C81E1E';
        }
        overlay.classList.remove('hidden', 'closing');
        isDocOpen = true;
        if (autoCloseTimer) clearTimeout(autoCloseTimer);
        if (autoClose) {
            autoCloseTimer = setTimeout(function () {
                closeDocument();
            }, 5000);
        }
    }
    function showCertificate(type) {
        stamp.className = 'stamp stamp-hidden';
        if (type === 'green') {
            stampText.textContent = 'APPROVED';
            docTypeText.textContent = 'Legal Transport Document';
            docTypeText.style.color = '#228B22';
            docStatusText.textContent = 'Awaiting Approval...';
            docStatusText.style.color = '#8c7b60';
        } else {
            stampText.textContent = 'SMUGGLED';
            docTypeText.textContent = 'Unregistered Document';
            docTypeText.style.color = '#C81E1E';
            docStatusText.textContent = 'Awaiting Approval...';
            docStatusText.style.color = '#8c7b60';
        }
        overlay.classList.remove('hidden', 'closing');
        isDocOpen = true;
        setTimeout(function () {
            stamp.classList.remove('stamp-hidden');
            stamp.classList.add(type);
            if (type === 'green') {
                docStatusText.textContent = 'Risk-Free - Approved';
                docStatusText.style.color = '#228B22';
            } else {
                docStatusText.textContent = 'Risky - Unregistered';
                docStatusText.style.color = '#C81E1E';
            }
        }, 1500);
        if (autoCloseTimer) clearTimeout(autoCloseTimer);
        autoCloseTimer = setTimeout(function () {
            closeDocument();
        }, 4500);
    }
    function closeDocument() {
        if (!isDocOpen) return;
        isDocOpen = false;
        if (autoCloseTimer) {
            clearTimeout(autoCloseTimer);
            autoCloseTimer = null;
        }
        overlay.classList.add('closing');
        setTimeout(function () {
            overlay.classList.add('hidden');
            overlay.classList.remove('closing');
            fetch('https://fetchq-fruitjob/closeDocument', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).catch(function () { });
        }, 300);
    }
    overlay.addEventListener('click', function (e) {
        if (e.target === overlay) closeDocument();
    });
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && isDocOpen) closeDocument();
    });
})();
