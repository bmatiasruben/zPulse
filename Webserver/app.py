import numpy as np
from flask import Flask, jsonify, request
from pathlib import Path
import json
import re
from zPulse.zPulse_overlay import zPulseOverlay
import threading
from hardware import generate_waveform

SCRIPT_DIR = Path(__file__).resolve().parent
bitstream_dir = SCRIPT_DIR / "zPulse" / "Bitstream"

app = Flask(__name__)

hw_lock = threading.Lock()
ol = None
CHANNELS = 8

def resolution_from_name(name: str) -> float:
    match = re.search(r'(\d+)_(\d+)', name)
    if not match:
        raise ValueError(f"Could not parse sampling rate from bitstream name: {name}")

    integer_part, decimal_part = match.groups()
    gbps = float(f"{integer_part}.{decimal_part}")

    if gbps <= 0:
        raise ValueError(f"Invalid sampling rate parsed from name: {gbps}")

    resolution_ps = 1000.0 / gbps
    return resolution_ps

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

@app.route('/api/load_bitstream', methods=['POST'])
def load_bitstream():
    global ol
    data = request.json
    name = data['name']
    bit_path = bitstream_dir / f"{name}.bit"
    # Check if file exists and also the .hwh
    if not bit_path.exists() or not bit_path.with_suffix('.hwh').exists():
        return jsonify(status="error", message=f"Bitstream '{name}' not found"), 404
    # Set resolution from filename
    try:
        resolution_ps = resolution_from_name(data['name'])
    except ValueError:
        resolution_ps = 62.5
    # Instantiate overlay 
    with hw_lock:
        try:
            ol = zPulseOverlay(str(bit_path))
        except Exception as e:
            return jsonify(status="error", message=f"Bitstream '{name}' could not be programmed"), 500
    return jsonify(status="ok", resolution=resolution_ps, channels=CHANNELS)

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
    
    return jsonify(status='ok')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=False)