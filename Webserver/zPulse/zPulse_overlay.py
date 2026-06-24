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
        # Check which DAC channels are enabled (from 0 to 7 based on DAC_ENABLED)
        for i in range(8):
            tx = getattr(self.tx_channels, f"tx_channel_{i}")
            self.ch_player[i] = self.memdict_to_view(f"tx_channels/tx_channel_{i}/axi_bram_ctrl_0")
            self.ch_enable[i] = tx.channel_ctrl_0.channel2[0]
            self.addr_limit[i] = tx.channel_ctrl_0.channel1
            self.preemph[i] = tx.emphasis_ctrl_0.channel1
            self.postemph[i] = tx.emphasis_ctrl_0.channel2
            self.amplitude[i] = tx.voltage_ctr_0.channel1

    def reset(self):
        self.reset_gpio.channel1[0].on()
        self.reset_gpio.channel1[0].off()
        
    def enable_channel(self, ch_index=None):
        if (isinstance(ch_index, int) and 0 <= ch_index <= 7):
            self.ch_enable[ch_index].on()
        
    def disable_channel(self, ch_index=None):
        if (isinstance(ch_index, int) and 0 <= ch_index <= 7):
            zero_waveform = [0] * self.ch_player[ch_index].shape[0]
            self.ch_player[ch_index][:] = zero_waveform
            self.ch_enable[ch_index].off()
                    
    def memdict_to_view(self, ip, dtype='int32'):
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
    