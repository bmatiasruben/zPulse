console.log("app.js loaded");
CHANNELS = 8;
let RESOLUTION = null;
const CHANNEL_COLORS = [
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728",
    "#9467bd", "#8c564b", "#e377c2", "#17becf"
];
function psToSteps(ps) {
    return Math.round(ps / RESOLUTION);
}

function stepsToPs(steps) {
    return steps * RESOLUTION;
}

function snapInputToResolution(inputId) {
    const input = document.getElementById(inputId);
    const rawPs = Number(input.value);
    const steps = psToSteps(rawPs);
    input.value = stepsToPs(steps);
    return steps;
}

function applyResolutionStepToInputs(ch) {
    document.getElementById(`period-${ch}`).step = RESOLUTION;
    document.getElementById(`delay-${ch}`).step = RESOLUTION;
    for (let p = 1; p <= pulseCounts[ch]; p++) {
        document.getElementById(`pulse${p}-width-${ch}`).step = RESOLUTION;
        document.getElementById(`pulse${p}-start-${ch}`).step = RESOLUTION;
    }
}

function populateChannelFromSettings(ch, settings) {
    document.getElementById(`period-${ch}`).value = stepsToPs(settings.period);
    document.getElementById(`delay-${ch}`).value = stepsToPs(settings.delay);
    document.getElementById(`pre-emph-${ch}`).value = settings.pre_emph;
    document.getElementById(`post-emph-${ch}`).value = settings.post_emph;
    document.getElementById(`amplitude-${ch}`).value = settings.amplitude;
    setEnableButton(ch, settings.enabled);

    // remove all existing pulse tabs beyond 1
    while (pulseCounts[ch] > 1) removePulse(ch, pulseCounts[ch]);

    // populate each pulse
    settings.pulses.forEach((pulse, index) => {
        const p = index + 1;
        if (p > 1) addPulse(ch);
        document.getElementById(`pulse${p}-width-${ch}`).value = stepsToPs(pulse.width);
        document.getElementById(`pulse${p}-start-${ch}`).value = stepsToPs(pulse.start);
    });

}

function fetchAndPopulateChannel(ch) {
    fetch(`/api/channel/${ch}`)
        .then(response => response.json())
        .then(data => {
            populateChannelFromSettings(ch, data.settings);
            updateChannelChart(ch, data.waveform);
        });
}

function fetchAndPopulateAllChannels() {
    for (let ch = 0; ch < CHANNELS; ch++) {
        fetchAndPopulateChannel(ch);
    }
}

function loadBitstreamList() {
    fetch('/api/bitstreams')
        .then(response => response.json())
        .then(data => {
            const dropdown = document.getElementById('bitstream-dropdown');
            data.bitstreams.forEach(name => {
                const option = document.createElement('option');
                option.value = name;
                option.textContent = name;
                dropdown.appendChild(option);
            });
        });
}

function resolutionFromName(name) {
    const match = name.match(/(\d+)(?:_(\d+))?/);
    if (!match) {
        return null;
    }
    const integerPart = match[1];
    const decimalPart = match[2] || '0';
    const gbps = parseFloat(`${integerPart}.${decimalPart}`);
    if (gbps <= 0) {
        return null;
    }
    return 1000.0 / gbps;
}

function buildPulseTabButton(ch, p) {
    return `
        <button class="pulse-tab-btn" id="pulse-tab-btn-${ch}-${p}" data-ch="${ch}" data-pulse="${p}">
            Pulse ${p}
            <span class="pulse-remove-btn" data-ch="${ch}" data-pulse="${p}">×</span>
        </button>
    `;
}
function buildPulseContentHTML(ch, p) {
    return `
        <div class="pulse-panel" id="pulse-panel-${ch}-${p}" style="display:none;">
            <div class="field-row">
                <label>Width (ps)</label>
                <input type="number" id="pulse${p}-width-${ch}" value="0">
            </div>
            <div class="field-row">
                <label>Start (ps)</label>
                <input type="number" id="pulse${p}-start-${ch}" value="0">
            </div>
        </div>
    `;
}
const pulseCounts = {};
for (let ch = 0; ch < CHANNELS; ch++) pulseCounts[ch] = 1;

function showPulseTab(ch, p) {
    const count = pulseCounts[ch];
    for (let i = 1; i <= count; i++) {
        document.getElementById(`pulse-panel-${ch}-${i}`).style.display = (i === p) ? 'block' : 'none';
        document.getElementById(`pulse-tab-btn-${ch}-${i}`).classList.toggle('active', i === p);
    }
}

function addPulse(ch) {
    if (pulseCounts[ch] >= 10) return;
    pulseCounts[ch]++;
    const p = pulseCounts[ch];
    const addBtn = document.getElementById(`pulse-add-${ch}`);
    addBtn.insertAdjacentHTML('beforebegin', buildPulseTabButton(ch, p));
    document.getElementById(`pulse-content-${ch}`).insertAdjacentHTML('beforeend', buildPulseContentHTML(ch, p));
    wirePulseInputs(ch, p);
    wirePulseTabButton(ch, p);
    if (RESOLUTION) applyResolutionStepToInputs(ch); // only if resolution known
    showPulseTab(ch, p);
    sendWaveformSettings(ch);
}

function rebuildPulseTabs(ch) {
    // collect current values before destroying anything
    const currentPulses = [];
    for (let p = 1; p <= pulseCounts[ch]; p++) {
        currentPulses.push({
            width: document.getElementById(`pulse${p}-width-${ch}`).value,
            start: document.getElementById(`pulse${p}-start-${ch}`).value
        });
    }

    // remove all existing pulse tab buttons and panels
    const tabBar = document.getElementById(`pulse-tab-bar-${ch}`);
    tabBar.querySelectorAll('.pulse-tab-btn').forEach(btn => btn.remove());
    document.getElementById(`pulse-content-${ch}`).innerHTML = '';

    // reset count
    pulseCounts[ch] = 0;

    // rebuild from saved values
    currentPulses.forEach(pulse => {
        pulseCounts[ch]++;
        const p = pulseCounts[ch];
        const addBtn = document.getElementById(`pulse-add-${ch}`);
        addBtn.insertAdjacentHTML('beforebegin', buildPulseTabButton(ch, p));
        document.getElementById(`pulse-content-${ch}`)
            .insertAdjacentHTML('beforeend', buildPulseContentHTML(ch, p));
        wirePulseTabButton(ch, p);
        wirePulseInputs(ch, p);
        document.getElementById(`pulse${p}-width-${ch}`).value = pulse.width;
        document.getElementById(`pulse${p}-start-${ch}`).value = pulse.start;
        if (RESOLUTION) {
            document.getElementById(`pulse${p}-width-${ch}`).step = RESOLUTION;
            document.getElementById(`pulse${p}-start-${ch}`).step = RESOLUTION;
        }
    });

    showPulseTab(ch, 1);
}

function removePulse(ch, p) {
    if (pulseCounts[ch] <= 1) return;

    // collect all values except the one being removed
    const remaining = [];
    for (let i = 1; i <= pulseCounts[ch]; i++) {
        if (i !== p) {
            remaining.push({
                width: document.getElementById(`pulse${i}-width-${ch}`).value,
                start: document.getElementById(`pulse${i}-start-${ch}`).value
            });
        }
    }

    // temporarily store remaining, then rebuild
    const savedCount = pulseCounts[ch];
    pulseCounts[ch] = remaining.length + 1; // trick: collect current first

    // actually just rebuild directly
    const tabBar = document.getElementById(`pulse-tab-bar-${ch}`);
    tabBar.querySelectorAll('.pulse-tab-btn').forEach(btn => btn.remove());
    document.getElementById(`pulse-content-${ch}`).innerHTML = '';
    pulseCounts[ch] = 0;

    remaining.forEach(pulse => {
        pulseCounts[ch]++;
        const newP = pulseCounts[ch];
        const addBtn = document.getElementById(`pulse-add-${ch}`);
        addBtn.insertAdjacentHTML('beforebegin', buildPulseTabButton(ch, newP));
        document.getElementById(`pulse-content-${ch}`)
            .insertAdjacentHTML('beforeend', buildPulseContentHTML(ch, newP));
        wirePulseTabButton(ch, newP);
        wirePulseInputs(ch, newP);
        document.getElementById(`pulse${newP}-width-${ch}`).value = pulse.width;
        document.getElementById(`pulse${newP}-start-${ch}`).value = pulse.start;
        if (RESOLUTION) {
            document.getElementById(`pulse${newP}-width-${ch}`).step = RESOLUTION;
            document.getElementById(`pulse${newP}-start-${ch}`).step = RESOLUTION;
        }
    });

    showPulseTab(ch, 1);
    sendWaveformSettings(ch);
}

function wirePulseTabButton(ch, p) {
    const btn = document.getElementById(`pulse-tab-btn-${ch}-${p}`);
    btn.addEventListener('click', function (e) {
        // ignore clicks on the × span — those are handled separately
        if (e.target.classList.contains('pulse-remove-btn')) return;
        showPulseTab(ch, p);
    });

    btn.querySelector('.pulse-remove-btn').addEventListener('click', function (e) {
        e.stopPropagation(); // prevent tab switching when clicking ×
        removePulse(ch, p);
    });
}

function wirePulseInputs(ch, p) {
    document.getElementById(`pulse${p}-width-${ch}`).addEventListener('change', () => sendWaveformSettings(ch));
    document.getElementById(`pulse${p}-start-${ch}`).addEventListener('change', () => sendWaveformSettings(ch));
}

// To avoid putting 8 times the same code in the html, 
// let's create it as a function that injects the code in the html file later
function buildChannelHTML(ch) {
    // let pulseRows = '';
    // for (let p = 1; p <= 10; p++) {
    //     pulseRows += buildPulseRowHTML(ch, p);
    // }

    return `
    <div class="channel" id="channel-${ch}">
        <div class="channel-columns">

            <div class="column">
                <h3>Channel Control</h3>
                <div class="field-row">
                    <label>Enable</label>
                    <button class="enable-btn" id="enable-btn-${ch}" data-ch="${ch}">OFF</button>
                </div>
                <div class="field-row">
                    <label>Period (ps)</label>
                    <input type="number" id="period-${ch}">
                </div>
                <div class="field-row">
                    <label>Delay (ps)</label>
                    <input type="number" id="delay-${ch}">
                </div>

                <h3>Pulses</h3>
                <div class="pulse-tab-bar" id="pulse-tab-bar-${ch}">
                    <button class="pulse-add-btn" id="pulse-add-${ch}">+</button>
                </div>
                <div id="pulse-content-${ch}"></div>
            </div>

            <div class="column">
                <h3>Drive Control</h3>
                <div class="field-row">
                    <label>Pre-emphasis</label>
                    <input type="number" id="pre-emph-${ch}" min="0" max="31">
                </div>
                <div class="field-row">
                    <label>Post-emphasis</label>
                    <input type="number" id="post-emph-${ch}" min="0" max="31">
                </div>
                <div class="field-row">
                    <label>Amplitude</label>
                    <input type="number" id="amplitude-${ch}" min="0" max="15">
                </div>
            </div>

        </div>
        <canvas id="chart-${ch}"></canvas>
    </div>
`;
}

const channelCharts = {};

function updateChannelChart(ch, waveform) {
    const periodPs = waveform.length * RESOLUTION;
    const useNs = periodPs > 1000;
    const labels = waveform.map((_, i) => {
        const ps = i * RESOLUTION;
        return useNs ? +(ps / 1000).toFixed(3) : ps;
    });

    if (!channelCharts[ch]) {
        const ctx = document.getElementById(`chart-${ch}`).getContext('2d');
        channelCharts[ch] = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    data: waveform,
                    stepped: true,
                    borderColor: CHANNEL_COLORS[ch],
                    fill: false,
                    pointRadius: 0
                }]
            },
            options: {
                animation: { duration: 100 },
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    x: {
                        title: {
                            display: true,
                            text: useNs ? 'Time (ns)' : 'Time (ps)'
                        },
                        ticks: {
                            maxTicksLimit: 8,
                            callback: function (value, index) {
                                const ps = index * RESOLUTION;
                                const displayVal = useNs ? ps / 1000 : ps;
                                return +displayVal.toFixed(1);
                            }
                        }
                    },
                    y: {
                        min: -0.1,
                        max: 1.1,
                        ticks: {
                            display: false
                        }
                    }
                }
            }
        });
    } else {
        channelCharts[ch].data.labels = labels;
        channelCharts[ch].data.datasets[0].data = waveform;
        channelCharts[ch].update();
    }
}

function buildTabButton(ch) {
    return `<button class="tab-button" data-channel="${ch}">Channel ${ch}</button>`;
}

function buildAllChannels() {
    const tabButtons = document.getElementById('tab-buttons');
    const container = document.getElementById('channels-container');

    for (let ch = 0; ch < CHANNELS; ch++) {
        tabButtons.insertAdjacentHTML('beforeend', buildTabButton(ch));
        container.insertAdjacentHTML('beforeend', buildChannelHTML(ch));

        // inject pulse 1
        const addBtn = document.getElementById(`pulse-add-${ch}`);
        addBtn.insertAdjacentHTML('beforebegin', buildPulseTabButton(ch, 1));
        document.getElementById(`pulse-content-${ch}`).insertAdjacentHTML('beforeend', buildPulseContentHTML(ch, 1));
        showPulseTab(ch, 1);
    }

    showTab(0);
}

function setEnableButton(ch, enabled) {
    const btn = document.getElementById(`enable-btn-${ch}`);
    if (enabled) {
        btn.textContent = 'ON';
        btn.classList.add('enabled');
    } else {
        btn.textContent = 'OFF';
        btn.classList.remove('enabled');
    }
}

function wireUpChannel(ch) {
    document.getElementById(`enable-btn-${ch}`).addEventListener('click', function () {
        const isEnabled = this.classList.contains('enabled');
        const newState = !isEnabled;

        fetch(`/api/channel/${ch}/enable`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ enable: newState })
        })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'ok') {
                    setEnableButton(ch, newState);
                }
            });
    });
    document.getElementById(`pulse-add-${ch}`).addEventListener('click', () => addPulse(ch));
    wirePulseTabButton(ch, 1);
    wirePulseInputs(ch, 1);
    ['pre-emph', 'post-emph', 'amplitude'].forEach(field => {
        document.getElementById(`${field}-${ch}`).addEventListener('change', () => sendDriveSettings(ch));
    });

    ['period', 'delay'].forEach(field => {
        document.getElementById(`${field}-${ch}`).addEventListener('change', () => sendWaveformSettings(ch));
    });
}

function wireUpAllChannels() {
    for (let ch = 0; ch < CHANNELS; ch++) {
        wireUpChannel(ch);
    }
}

function showTab(ch) {
    for (let i = 0; i < CHANNELS; i++) {
        document.getElementById(`channel-${i}`).style.display = (i === ch) ? 'block' : 'none';
        document.querySelectorAll('.tab-button')[i].classList.toggle('active', i === ch);
    }
}

function wireUpTabButtons() {
    document.querySelectorAll('.tab-button').forEach(btn => {
        btn.addEventListener('click', function () {
            const ch = Number(this.dataset.channel);
            showTab(ch);
        });
    });
}



document.getElementById('bitstream-dropdown').addEventListener('change', function () {
    const name = this.value;
    const resolution = resolutionFromName(name);
    document.getElementById('resolution').value = resolution !== null ? resolution : '';
    RESOLUTION = resolution;
    for (let i = 0; i < CHANNELS; i++) {
        applyResolutionStepToInputs(i);
    }
});

document.getElementById('load-bitstream-btn').addEventListener('click', function () {
    const selectedName = document.getElementById('bitstream-dropdown').value;
    if (!selectedName) {
        alert('Select a bitstream first.');
        return;
    }

    fetch('/api/load_bitstream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: selectedName })
    })
        .then(response => response.json())
        .then(data => {
            console.log(data)
            if (data.status == 'ok') {
                document.getElementById('bitstream-selector').style.display = 'block';
                document.getElementById('channel-gui').style.display = 'block';
                fetchAndPopulateAllChannels();
            } else {
                alert('Failed to load bitstream: ' + data.message);
            }
        });
});


function sendDriveSettings(ch) {
    fetch(`/api/channel/${ch}/drive`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            pre_emph: Number(document.getElementById(`pre-emph-${ch}`).value),
            post_emph: Number(document.getElementById(`post-emph-${ch}`).value),
            amplitude: Number(document.getElementById(`amplitude-${ch}`).value)
        })
    })
        .then(response => response.json())
        .then(data => console.log(data));
}

function sendWaveformSettings(ch) {
    const period = snapInputToResolution(`period-${ch}`);
    const delay = snapInputToResolution(`delay-${ch}`);

    const numPulses = pulseCounts[ch];
    const pulses = [];
    for (let p = 1; p <= numPulses; p++) {
        const width = snapInputToResolution(`pulse${p}-width-${ch}`);
        const start = snapInputToResolution(`pulse${p}-start-${ch}`);
        pulses.push({ width, start });
    }

    fetch(`/api/channel/${ch}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ period, delay, pulses })
    })
        .then(response => response.json())
        .then(data => {
            console.log(data);
            updateChannelChart(ch, data.waveform);
        });
}

fetch('/api/status')
    .then(r => r.json())
    .then(data => {
        if (data.loaded) {
            document.getElementById('bitstream-selector').style.display = 'block';
            document.getElementById('channel-gui').style.display = 'block';
            const resolution = resolutionFromName(data.bitstream_name);
            document.getElementById('resolution').value = resolution !== null ? resolution : '';
            RESOLUTION = resolution;
            for (let i = 0; i < CHANNELS; i++) {
                applyResolutionStepToInputs(i);
            }
            fetchAndPopulateAllChannels();
        } else {
            document.getElementById('bitstream-selector').style.display = 'block';
            document.getElementById('channel-gui').style.display = 'none';
        }
    });

loadBitstreamList();
buildAllChannels();
wireUpAllChannels();
wireUpTabButtons();