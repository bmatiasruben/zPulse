**zPulse** is a Pynq-based pulse generator for the ZCU102 platform. Can in principle be expanded to any Zynq Ultrascale+ board with transceivers available. The design itself is not complex or complicated, but I've found very little references on using transceivers combined with Pynq online.

**DISCLAIMER**: For this design I'm using a file called DACRAMstreamer.v. That file is a modified version from one that can be found on the [RFSoC 4x2 MTS example](https://github.com/Xilinx/RFSoC-MTS). Nevertheless, it's not an extremely complex code, but didn't want to waste time making my own.

# Features

This design allows you to create pulses using the Zynq Ultrascale+ Transceiver channels, allowing you to add an arbitrary amount of pulses (>1024) that can be as small as 62.5 ps wide. The system works for up to 8 channels and can store waveforms up to ~130 μs. This number can be easily increased by just reducing the number of channels, and further increased by adding some compresion algorithm.

The waveform for each channel can be configured independently, including period and number of pulses, allowing precise alignment control even after different-length cables at the output. The delays and width you can set are very precise and reproduceable, which is a key requirement for some applications (like my own).

Moreover, when modifying any of the waveforms, the system does not power-off and then on, allowing the signals to maintain phase-locking with any detection device at the output, yet another key requirement for some applications.

Finally, it allows you to save and load settings for all channels, since at re-compilation of the GUI all settings are lost (_oops_).

# Installation

Installing this is a fairly lengthy process, mainly because it changes from board to board, but the steps are all there, just difficult to find all together.

First start cloning the repository with

```bash
git clone --recurse-submodules https://github.com/bmatiasruben/zPulse.git
```

for Git 2.13 or later, or with

```bash
git clone --recursive https://github.com/bmatiasruben/zPulse.git
```

for Git 1.65 or later. This will download the entire repository including the Hog submodule.

## Vivado side

To clone the Vivado project, I am currently using [HOG](https://github.com/Hog-CERN/Hog) to do version control, so follow their instructions to re-create the project. To do so, open a bash console and run

```bash
cd zPulse
./Hog/Do CREATE zPulse
```

which will re-create the Vivado project inside `zPulse/Projects/zPulse`.

The version used was Vivado 2024.2. Even though the board used was the ZCU102, all blocks are present in most Zynq Ultrascale+ chips, just check that the board to use has the transceiver ports available. When trying to do this for a separate board, I recommend doing so for the ZCU102 board and then copying the structure for your own system.

<p align="center">
<img src="./images/block_design.jpg" width="90%"/>
<img src="./images/tx_channel.png" width="80%"/>
</p>

When re-generating the project you might see that the input clock frequency for the Transceiver Wizard is 148.5 MHz instead of the standard 156.25 MHz. That is because ZCU102 requires Ubuntu for Pynq to work, and installing Ubuntu changes the frequency of the Si570 to that 148.5 MHz. If using a different board, check if the frequency is correct.

## Pynq side

If using a board already compatible with Pynq, then you can skip the next subsection and go directly with a standard Pynq installation or pre-built image.

### Ubuntu installation

If your board is compatible with installing Pynq with Ubuntu on the back side (ZCU102, Kria KV260 and Kria KR260), you need to install Ubuntu first before doing anything. When doing so, I followed the tutorial within [ATchelet/ZCU102-PYNQ](https://github.com/ATchelet/ZCU102-PYNQ). Even though some text is incorrect and still talks about the Kria KV260, the content is correct.

Make sure to install [Ubuntu version 20.04](https://ubuntu.com/download/amd). I tried installing version 22.04 but I didn't manage to make it work, so I stopped testing (it might be compatible with some fix, but I'm not an expert in Ubuntu to try to fix it).

# Use

Once the Vivado project is recreated and the bitstream is generated, you will have the two files required for the Pynq Overlay (.hwh and .bit).

Within the Pynq folder, you will find the file zPulse_overlay.py which is a custom class to make control of the pulse generation with transceivers easier, zPulse_GUI.ipynb that is the full GUI for controlling all channels.

To start the GUI, just run the only cell present in zPulse_GUI.ipynb. From within the GUI, you can control everything you need, from pulse width, pulse offset, number of pulses, and overall waveform period.

<p align="center">
<img src="./images/pynq_gui.png" width="95%"/>
</p>

# Contribute

If you regenerate this design for a different FPGA board that is not the ZCU102, please let me know and it can be added within this same repository. Hog allows you to control separate projects (aimed for different boards for example), so it is easy to integrate new board designs.

Any bug or problem that you find please report it as an issue.
