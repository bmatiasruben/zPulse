#  -------------------------------------------------------------------------------------------------
#  Copyright (C) 2025 Matías Rubén Bolaños Wagner
#  SPDX-License-Identifier: GPL-3.0-or-later
#  ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --
from pynq import Overlay, MMIO, GPIO
import numpy as np
import os
import math

CHANNELS: int = 8  #: Number of channels
MEMORY_SIZE: int = 262144 #: Memory Size
MEMORY_WIDTH: int = 64

PHASE_REF_CHANNEL: int = 0  #: Channel 0 is the phase reference (no fine phase control)
PHASE_STEPS_PER_UI: int = 64  #: TX phase interpolator codes per UI (GTH)
PHASE_MAX_CODES: int = PHASE_STEPS_PER_UI - 1  #: Fine phase range, coarser shifts use the delay
PHASE_APPLY = 1 << 16
PHASE_REALIGN = 1 << 17
PHASE_RESET = 1 << 31

def lcm(a: int, b: int) -> int:
    return int(a * b / math.gcd(a, b))

def binary_array_to_integers(bits):
    """Convert a 0/1 numpy array into little-endian 32-bit integers.
       bits[0] is the earliest (LSB) within each 32-bit group."""
    n = len(bits)
    pad = (-n) % 32
    if pad:
        bits = np.concatenate([bits, np.zeros(pad, dtype=int)])
    ints = []
    # Little-endian within each 32-bit word: bit0 is LSB
    for i in range(0, len(bits), 32):
        word = 0
        # assemble 32 bits
        for b in range(32):
            word |= (int(bits[i + b]) & 1) << b
        ints.append(word)
    return ints

class zPulseOverlay(Overlay):
    def __init__(self, bitfile_name=None, **kwargs):
        """Construct a new zPulseOverlay

        bitfile_name: path to the bitstream file. Should have the .hwh file in the same directory as the .bit file with the same name.

        """
        super().__init__(bitfile_name, **kwargs)
        
        board = os.environ['BOARD']
        
        self.ch_player = {}
        self.ch_enable = {}
        self.addr_limit = {}
        self.preemph = {}
        self.postemph = {}
        self.amplitude = {}
        self.phase_ctrl = {}
        self.phase_status = {}
        self._phase_target = {}
        # Check which DAC channels are enabled (from 0 to 7 based on DAC_ENABLED)
        for i in range(8):
            tx = getattr(self.tx_channels, f"tx_channel_{i}")
            self.ch_player[i] = self.memdict_to_view(f"tx_channels/tx_channel_{i}/axi_bram_ctrl_0")
            self.ch_enable[i] = tx.channel_ctrl_0.channel2[0]
            self.addr_limit[i] = tx.channel_ctrl_0.channel1
            self.preemph[i] = tx.emphasis_ctrl_0.channel1
            self.postemph[i] = tx.emphasis_ctrl_0.channel2
            self.amplitude[i] = tx.voltage_ctr_0.channel1
            # Fine phase control (TX phase interpolator), only in bitstreams that include it
            if i != PHASE_REF_CHANNEL and hasattr(tx, "phase_ctrl_0"):
                self.phase_ctrl[i] = tx.phase_ctrl_0.channel1
                self.phase_status[i] = tx.phase_ctrl_0.channel2
                self._phase_target[i] = 0

    def reset(self):
        self.reset_gpio.channel1[0].on()
        self.reset_gpio.channel1[0].off()
        
    def enable_channel(self, ch_index=None):
        if (isinstance(ch_index, int) and 0 <= ch_index <= 7):
            self.ch_enable[ch_index].on()
        
    def disable_channel(self, ch_index=None):
        if (isinstance(ch_index, int) and 0 <= ch_index <= 7):
            self.ch_enable[ch_index].off()
                    
    def has_phase_control(self, ch_index=None):
        return ch_index in self.phase_ctrl

    def set_phase(self, ch_index, codes):
        """Set the fine phase offset of a channel in TX PI codes (1/64 UI), relative to the
        phase reached by the automatic alignment. The setpoint is held in the PL, so it
        survives reset() (which clears the AXI GPIOs)."""
        if not self.has_phase_control(ch_index):
            raise ValueError(f"Channel {ch_index} has no phase control (channel {PHASE_REF_CHANNEL} is the reference)")
        codes = int(codes)
        if not 0 <= codes <= PHASE_MAX_CODES:
            raise ValueError(f"Phase must be between 0 and {PHASE_MAX_CODES} codes")
        self._phase_target[ch_index] = codes
        self.phase_ctrl[ch_index].write(codes | PHASE_APPLY, 0xFFFFFFFF)

    def get_phase_status(self, ch_index):
        status = self.phase_status[ch_index].read()
        return {
            "offset": status & 0x7F,
            "raw": (status >> 8) & 0x7F,
            "aligned": bool(status >> 16 & 1),
            "busy": bool(status >> 17 & 1),
            "tx_reset_done": bool(status >> 18 & 1),
        }

    def _phase_pulse(self, ch_index, flag):
        target = self._phase_target[ch_index]
        self.phase_ctrl[ch_index].write(target | flag, 0xFFFFFFFF)
        self.phase_ctrl[ch_index].write(target | PHASE_APPLY, 0xFFFFFFFF)

    def fine_realign_phase(self, ch_index):
        """Redo only the fine alignment of a channel to the half-response of its phase detector."""
        self._phase_pulse(ch_index, PHASE_REALIGN)

    def realign_phase(self, ch_index):
        """Restart the automatic alignment of a channel (the phase offset is re-applied afterwards)."""
        self._phase_pulse(ch_index, PHASE_RESET)

    def memdict_to_view(self, ip, dtype='uint32'):
        """ Configures access to internal memory via MMIO"""
        baseAddress = self.mem_dict[ip]["phys_addr"]
        mem_range = self.mem_dict[ip]["addr_range"]
        ipmmio = MMIO(baseAddress, mem_range)
        return ipmmio.array[0:ipmmio.length].view(dtype)
    
    def send_waveform_to_memory(self, ch_idx, waveform):
        period = len(waveform)
        repetition_factor = int(lcm(period, MEMORY_WIDTH) / period)
        extended_waveform = np.tile(waveform, repetition_factor)
        int_waveform_to_memory = binary_array_to_integers(extended_waveform)
        addr_limit = len(int_waveform_to_memory)
        self.ch_player[ch_idx][:addr_limit] = int_waveform_to_memory
        self.addr_limit[ch_idx].write(addr_limit * 4 - MEMORY_WIDTH//8, 0xFFFFFFF)
    
