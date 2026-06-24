import os
import json
import logging
from pathlib import Path
from typing import Dict, Optional, Tuple, List
import numpy as np
from zPulse.zPulse_overlay import zPulseOverlay

DEFAULT_PERIOD: float = None  #: Default period in ps
DEFAULT_WIDTH: float = None  #: Default width of pulses
DEFAULT_START_POSITION: float = None  #: Default start position for the pulses
    
DEFAULT_NUM_PULSES: int = 1  #: Default number of channels
DEFAULT_GLOBAL_DELAY: float = 0  #: Default delay on the whole channel
MAX_PULSES: int = 10  #: Maximum number of pulses per channel

DEFAULT_PRE_EMPH: int = 0
DEFAULT_POST_EMPH: int = 0
DEFAULT_AMPLITUDE: int = 15

global_combined_waveforms = {
    i: np.array([0]*64) for i in range(8)
}  # Global variables to store waveforms per channel


def generate_pulse(pulse_width_step: int, start_point_step: int, period_step: int) -> np.ndarray:
    pulse_width_step = max(0, min(pulse_width_step, period_step))
    start_point_step = max(0, min(start_point_step, period_step - 1))
    end_point_step = min(start_point_step + pulse_width_step, period_step)

    waveform = np.zeros(period_step, dtype=int)
    if end_point_step > start_point_step:
        waveform[start_point_step:end_point_step] = 1
    return waveform

def generate_waveform(period: int, delay: int, pulses:List[Dict[int, int]]) -> np.ndarray:
    combined_waveform = np.zeros(period, dtype=int)
    num_pulses = len(pulses)

    for i in range(num_pulses):
        waveform = generate_pulse(pulses[i]['width'], pulses[i]['start'], period)
        combined_waveform = np.maximum(combined_waveform, waveform)
    combined_waveform = np.roll(combined_waveform, delay)
    
    return combined_waveform

