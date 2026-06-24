console.log("app.js loaded");
CHANNELS = 8;
let RESOLUTION = null;

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
    for (let p = 1; p <= 10; p++) {
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
    document.getElementById(`enable-${ch}`).checked = settings.enabled;

    const numPulses = settings.pulses.length;
    document.getElementById(`num-pulses-${ch}`).value = numPulses;
    setVisiblePulseCount(ch, numPulses);

    settings.pulses.forEach((pulse, index) => {
        const p = index + 1; // pulse numbering is 1-based
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

function buildPulseRowHTML(ch, p) {
    const hidden = p === 1 ? '' : 'style="display: none;"';
    return `
        <div class="pulse-row" id="pulse${p}-row-${ch}" ${hidden}>
            <label>Pulse ${p} Width:</label>
            <input type="number" id="pulse${p}-width-${ch}" value="0">
            <label>Start:</label>
            <input type="number" id="pulse${p}-start-${ch}" value="0">
        </div>
    `;
}

function setVisiblePulseCount(ch, n) {
    for (let p = 1; p <= 10; p++) {
        document.getElementById(`pulse${p}-row-${ch}`).style.display = (p <= n) ? 'block' : 'none';
    }
    document.getElementById(`num-pulses-label-${ch}`).textContent = n;
}

// To avoid putting 8 times the same code in the html, 
// let's create it as a function that injects the code in the html file later
function buildChannelHTML(ch) {
    let pulseRows = '';
    for (let p = 1; p <= 10; p++) {
        pulseRows += buildPulseRowHTML(ch, p);
    }

    return `
        <div class="channel" id="channel-${ch}">
            <h2>Channel ${ch}</h2>
            <label>Enable:</label>
            <input type="checkbox" id="enable-${ch}">

            <label>Period (ps):</label>
            <input type="number" id="period-${ch}">
            <label>Delay (ps):</label>
            <input type="number" id="delay-${ch}">

            <h3>Drive Controls</h3>
            <label>Pre-emphasis:</label>
            <input type="number" id="pre-emph-${ch}" min="0" max="31">
            <label>Post-emphasis:</label>
            <input type="number" id="post-emph-${ch}" min="0" max="31">
            <label>Amplitude:</label>
            <input type="number" id="amplitude-${ch}" min="0" max="15">

            <h3>Pulses</h3>
            <label>Number of pulses:</label>
            <input type="range" id="num-pulses-${ch}" min="1" max="10" value="1">
            <span id="num-pulses-label-${ch}">1</span>

            ${pulseRows}

            <canvas id="chart-${ch}"></canvas>
        </div>
    `;
}

const channelCharts = {};

function updateChannelChart(ch, waveform) {
    const labels = waveform.map((_, i) => i); // x-axis: step index

    if (!channelCharts[ch]) {
        const ctx = document.getElementById(`chart-${ch}`).getContext('2d');
        channelCharts[ch] = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    data: waveform,
                    stepped: true,
                    borderColor: 'blue',
                    fill: false,
                    pointRadius: 0
                }]
            },
            options: {
                scales: {
                    y: {
                        min: -0.1,
                        max: 1.1
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
    }

    showTab(0); // default to first tab
}

function wireUpChannel(ch) {
    document.getElementById(`enable-${ch}`).addEventListener('change', function () {
        fetch(`/api/channel/${ch}/enable`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ enable: this.checked })
        })
            .then(response => response.json())
            .then(data => console.log(data));
    });

    ['pre-emph', 'post-emph', 'amplitude'].forEach(field => {
        document.getElementById(`${field}-${ch}`).addEventListener('change', () => sendDriveSettings(ch));
    });

    ['period', 'delay'].forEach(field => {
        document.getElementById(`${field}-${ch}`).addEventListener('change', () => sendWaveformSettings(ch));
    });
    document.getElementById(`num-pulses-${ch}`).addEventListener('input', function () {
        const n = Number(this.value);
        setVisiblePulseCount(ch, n);
        sendWaveformSettings(ch);
    });
    for (let p = 1; p <= 10; p++) {
        document.getElementById(`pulse${p}-width-${ch}`).addEventListener('change', () => sendWaveformSettings(ch));
        document.getElementById(`pulse${p}-start-${ch}`).addEventListener('change', () => sendWaveformSettings(ch));
    }
}

function wireUpAllChannels() {
    for (let ch = 0; ch < CHANNELS; ch++) {
        wireUpChannel(ch);
    }
}

function showTab(ch) {
    for (let i = 0; i < CHANNELS; i++) {
        document.getElementById(`channel-${i}`).style.display = (i === ch) ? 'block' : 'none';
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

    const numPulses = Number(document.getElementById(`num-pulses-${ch}`).value);
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