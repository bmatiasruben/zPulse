#  -------------------------------------------------------------------------------------------------
#  Copyright (C) 2025 Matías Rubén Bolaños Wagner
#  SPDX-License-Identifier: GPL-3.0-or-later
#  ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --
from pynq import Overlay, MMIO, GPIO
import os

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
        # Check which DAC channels are enabled (from 0 to 7 based on DAC_ENABLED)
        for i in range(8):
            self.ch_player[i] = self.memdict_to_view(f"tx_channels/tx_channel_{i}/axi_bram_ctrl_0")
        self.ch_enable[0] = self.tx_channels.tx_channel_0.channel_ctrl_0.channel2[0]
        self.ch_enable[1] = self.tx_channels.tx_channel_1.channel_ctrl_0.channel2[0]
        self.ch_enable[2] = self.tx_channels.tx_channel_2.channel_ctrl_0.channel2[0]
        self.ch_enable[3] = self.tx_channels.tx_channel_3.channel_ctrl_0.channel2[0]
        self.ch_enable[4] = self.tx_channels.tx_channel_4.channel_ctrl_0.channel2[0]
        self.ch_enable[5] = self.tx_channels.tx_channel_5.channel_ctrl_0.channel2[0]
        self.ch_enable[6] = self.tx_channels.tx_channel_6.channel_ctrl_0.channel2[0]
        self.ch_enable[7] = self.tx_channels.tx_channel_7.channel_ctrl_0.channel2[0]
        
        self.addr_limit[0] = self.tx_channels.tx_channel_0.channel_ctrl_0.channel1
        self.addr_limit[1] = self.tx_channels.tx_channel_1.channel_ctrl_0.channel1
        self.addr_limit[2] = self.tx_channels.tx_channel_2.channel_ctrl_0.channel1
        self.addr_limit[3] = self.tx_channels.tx_channel_3.channel_ctrl_0.channel1
        self.addr_limit[4] = self.tx_channels.tx_channel_4.channel_ctrl_0.channel1
        self.addr_limit[5] = self.tx_channels.tx_channel_5.channel_ctrl_0.channel1
        self.addr_limit[6] = self.tx_channels.tx_channel_6.channel_ctrl_0.channel1
        self.addr_limit[7] = self.tx_channels.tx_channel_7.channel_ctrl_0.channel1

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
    
        
        
    