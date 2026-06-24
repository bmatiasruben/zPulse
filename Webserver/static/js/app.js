async function loadSettings(filename) {
    const resp = await fetch('/api/settings/load', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename })
    });
    const settings = await resp.json();

    for (let ch = 0; ch < 8; ch++) {
        showProgress(`Loading channel ${ch + 1} of 8...`);
        await applyChannelSettings(ch, settings[ch]);
    }
    showProgress('Done');
}

async function applyChannelSettings(ch, chSettings) {
    // 1. populate UI controls directly (no onChange triggers)
    setChannelUI(ch, chSettings);

    // 2. push to hardware
    await fetch(`/api/channel/${ch}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            period: chSettings.period,
            delay: chSettings.delay,
            pulses: chSettings.pulses
        })
    }).then(r => r.json()).then(data => updateChart(ch, data.waveform));

    await fetch(`/api/channel/${ch}/drive`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            pre_emph: chSettings.pre_emph,
            post_emph: chSettings.post_emph,
            amplitude: chSettings.amplitude
        })
    });

    if (chSettings.enabled) {
        await fetch(`/api/channel/${ch}/enable`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ enable: true })
        });
    }
}