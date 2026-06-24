from flask import Flask, jsonify, request, render_template
from pathlib import Path
from zPulse.zPulse_overlay import zPulseOverlay
import threading
from hardware import generate_waveform
import copy

SCRIPT_DIR = Path(__file__).resolve().parent
bitstream_dir = SCRIPT_DIR / "zPulse" / "Bitstream"

app = Flask(__name__)

hw_lock = threading.Lock()
ol = None
current_bitstream_name = None
CHANNELS = 8
DEFAULT_SETTINGS = {
    "period": 20,
    "delay": 0,
    "pulses": [{"width": 5, "start": 0}],
    "pre_emph": 0,
    "post_emph": 0,
    "amplitude": 15,
    "enabled": False
}

channel_settings = {
    ch: copy.deepcopy(DEFAULT_SETTINGS) for ch in range(CHANNELS)
}

@app.route("/")
def index():
    return render_template("index.html")

@app.route('/api/status', methods=['GET'])
def get_status():
    return jsonify(loaded=(ol is not None), bitstream_name=current_bitstream_name)

@app.route('/api/bitstreams', methods=['GET'])
def get_bitstreams():
    if not bitstream_dir.exists():
        return jsonify(bitstreams=[], error="Bitstream directory not found"), 404
    
    # Collect all .bit files and check for matching .hwh
    all_bit_files = list(bitstream_dir.glob("*.bit"))
    bit_files = []
    for bit_file in all_bit_files:
        hwh_file = bit_file.with_suffix(".hwh")
        if hwh_file.exists():
            bit_files.append(bit_file)
        else:
            print(f"Skipping '{bit_file.name}': missing '{hwh_file.name}'")

    if not bit_files:
        return jsonify(bitstreams=[], error="No matching .bit/.hwh pairs found"), 404

    return jsonify(bitstreams=[f.stem for f in bit_files])

defaults_applied = False

@app.route('/api/load_bitstream', methods=['POST'])
def load_bitstream():
    global ol, current_bitstream_name, defaults_applied
    data = request.json
    name = data['name']
    bit_path = bitstream_dir / f"{name}.bit"

    if not bit_path.exists() or not bit_path.with_suffix('.hwh').exists():
        return jsonify(status="error", message=f"Bitstream '{name}' not found"), 404

    with hw_lock:
        try:
            ol = zPulseOverlay(str(bit_path))
        except Exception as e:
            app.logger.exception(f"Failed to program bitstream '{name}'")
            return jsonify(status="error", message=f"Bitstream '{name}' could not be programmed"), 500

    current_bitstream_name = name

    if not defaults_applied:
        for ch in range(CHANNELS):
            settings = channel_settings[ch]
            waveform = generate_waveform(settings['period'], settings['delay'], settings['pulses'])
            with hw_lock:
                ol.send_waveform_to_memory(ch, waveform)
                ol.preemph[ch].write(settings['pre_emph'], 0xFFFFFFF)
                ol.postemph[ch].write(settings['post_emph'], 0xFFFFFFF)
                ol.amplitude[ch].write(2 * settings['amplitude'], 0xFFFFFFF)
                if settings['enabled']:
                    ol.enable_channel(ch)
        defaults_applied = True

    return jsonify(status="ok", channels=CHANNELS)

@app.route('/api/channel/<int:ch>', methods=['GET'])
def get_channel_settings(ch):
    if not (0 <= ch < CHANNELS):
        return jsonify(status="error", message=f"Invalid channel: {ch}"), 400
    settings = channel_settings[ch]
    waveform = generate_waveform(settings['period'], settings['delay'], settings['pulses'])
    return jsonify(status="ok", settings=settings, waveform=waveform.tolist())

@app.route('/api/channel/<int:ch>', methods=['POST'])
def update_channel(ch):
    if ol is None:
        return jsonify(status="error", message="No bitstream loaded"), 400
    if not (0 <= ch < CHANNELS):
        return jsonify(status="error", message=f"Invalid channel: {ch}"), 400

    data = request.json
    period = data['period']
    delay = data['delay']
    pulses = data['pulses']

    waveform = generate_waveform(period, delay, pulses)
    with hw_lock:
        ol.send_waveform_to_memory(ch, waveform)
    channel_settings[ch]['period'] = period
    channel_settings[ch]['delay'] = delay
    channel_settings[ch]['pulses'] = pulses
    return jsonify(status='ok', waveform=waveform.tolist())

@app.route('/api/channel/<int:ch>/enable', methods=['POST'])
def set_channel_enable(ch):
    if ol is None:
        return jsonify(status="error", message="No bitstream loaded"), 400

    if not (0 <= ch < CHANNELS):
        return jsonify(status="error", message=f"Invalid channel: {ch}"), 400

    data = request.json
    enable = data['enable']

    with hw_lock:
        if enable:
            ol.enable_channel(ch)
        else:
            ol.disable_channel(ch)
    channel_settings[ch]['enabled'] = enable

    return jsonify(status='ok', enabled=enable)

@app.route('/api/channel/<int:ch>/drive', methods=['POST'])
def set_channel_drive(ch):
    if ol is None:
        return jsonify(status="error", message="No bitstream loaded"), 400

    if not (0 <= ch < CHANNELS):
        return jsonify(status="error", message=f"Invalid channel: {ch}"), 400

    data = request.json
    amplitude = data['amplitude']
    pre_emph = data['pre_emph']
    post_emph = data['post_emph']
    with hw_lock:
        ol.preemph[ch].write(pre_emph, 0xFFFFFFF)
        ol.postemph[ch].write(post_emph, 0xFFFFFFF)
        ol.amplitude[ch].write(2 * amplitude, 0xFFFFFFF)
    channel_settings[ch]['amplitude'] = amplitude
    channel_settings[ch]['pre_emph'] = pre_emph
    channel_settings[ch]['post_emph'] = post_emph
    
    return jsonify(status='ok')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=False)