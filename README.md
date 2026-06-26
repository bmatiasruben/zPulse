# zPulse

**zPulse** is a Pynq-based pulse generator for the ZCU102 platform. Can in principle be expanded to any Zynq Ultrascale+ board with transceivers available. The design itself is not complex or complicated, but I've found very little references on using transceivers combined with Pynq online.

**DISCLAIMER**: For this design I was using a file called DACRAMstreamer.v. That file is a modified version from one that can be found on the [RFSoC 4x2 MTS example](https://github.com/Xilinx/RFSoC-MTS). Nevertheless, it's not an extremely complex code, but didn't want to waste time making my own.

**DISCLAIMER UPDATE**: I did create my own, and is now within Sources/BRAM_streamer_data.vhd

**NEW DISCLAIMER**: AI was used in this project for two things. First, for the backend I used it to guide me on what to do next and what documentation to read (mainly to learn how to do it myself), while still implementing it myself and writing my own code. For the frontend and the installation script, on the other hand, it was fully AI generated and just copy-pasted.

## Features

This design allows you to create pulses using the Zynq Ultrascale+ Transceiver channels, allowing you to add an arbitrary amount of pulses (>1024) that can be as small as 62.5 ps wide. The system works for up to 8 channels and can store waveforms up to ~130 μs. This number can be easily increased by just reducing the number of channels, and further increased by adding some compresion algorithm.

The waveform for each channel can be configured independently, including period and number of pulses, allowing precise alignment control even after different-length cables at the output. The delays and width you can set are very precise and reproduceable, which is a key requirement for some applications (like my own).

Moreover, when modifying any of the waveforms, the system does not power-off and then on, allowing the signals to maintain phase-locking with any detection device at the output, yet another key requirement for some applications.

Finally, it allows you to save and load settings for all channels, since at re-compilation of the GUI all settings are lost (_oops_).

## Installation

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

### Vivado side

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

When re-generating the project you might see that the input clock frequency for the Transceiver Wizard is 100 MHz instead of the standard 156.25 MHz. That is because the design was created to be able to eventually lock to an external 100 MHz clock, so the Si570 oscillator has to be reconfigured to match this frequency. To do so, I am including a C script that can be compiled from Pynq's terminal that reprograms the oscillator to match this frequency.

Once the project is re-generated (and re-compiled), you require two files from here that are the bitstream (.bit) and the hardware handoff (.hwh). Those files are located in

```bash
.bit <- $REPO_DIR/Projects/zPulse/zPulse.runs/impl_1/Top.bit
.hwh <- $REPO_DIR/Projects/zPulse/zPulse.gen/sources_1/bd/zcu102_zpulse/hw_handoff/zcu102_zpulse.hwh
```
Alternatively, if you set up the Hog repo correctly and you didn't mess it up too much, you should be able to find the bitstream file also within 

```bash
.bit <- $REPO_DIR/bin/zPulse-vX.X.X-HASH
```

Where X.X.X is the tag you are working on and HASH is the commit hash from git.

### Pynq side

If using a board already compatible with Pynq, then you can skip the next subsection and go directly with a standard Pynq installation or pre-built image.

#### Ubuntu installation

If your board is compatible with installing Pynq with Ubuntu on the back side (ZCU102, Kria KV260 and Kria KR260), you need to install Ubuntu first before doing anything. When doing so, I followed the tutorial within [ATchelet/ZCU102-PYNQ](https://github.com/ATchelet/ZCU102-PYNQ). Even though some text is incorrect and still talks about the Kria KV260, the content is correct.

Make sure to install [Ubuntu version 20.04](https://ubuntu.com/download/amd). I tried installing version 22.04 but I didn't manage to make it work, so I stopped testing (it might be compatible with some fix, but I'm not an expert in Ubuntu to try to fix it).

Once Ubuntu is installed, follow up by 
```bash
git clone https://github.com/ATchelet/ZCU102-PYNQ.git
cd ZCU102-PYNQ/
sudo bash install.sh
```

To define a custom IP for your system (highly recommended), you have to edit the file ```bash etc/netplan/01-netcfg.yaml``` so its contents are
```bash 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.XX.YYY/24
      gateway4: 192.168.XX.ZZZ
      nameservers:
          addresses: [8.8.8.8, 4.4.4.4]
```
Where ZZZ is the gateway you are using on the network. The relevant part is that both the XX parts for the address and the gateway are equal.

#### zPulse installation

Once the Vivado project is recreated and the bitstream is generated, you will have the two files required for the Pynq Overlay (.hwh and .bit). This step can be skipped if using the provided files in the last release.

To enter the Pynq GUI, just type 192.168.XX.YYY:9090/lab (where 192.168.XX.YYY is the IP you set chose on the ```etc/netplan/01-netcfg.yaml``` file). The password to enter the GUI will be xilinx. From here, you can SSH into the board or just enter through the Pynq GUI and open a new terminal. From any of those two, just run:

```bash
curl -sSL https://raw.githubusercontent.com/bmatiasruben/zPulse/main/install.sh | sudo bash
```

This single command will:

- Clone the zPulse repository onto the board
- Download the latest bitstream release assets (.bit and .hwh files)
- Deploy the web server to `/home/ubuntu/Webserver`
- Deploy the Jupyter notebook and overlay to `/home/root/jupyter_notebooks`
- Compile the Si570 clock utility
- Auto-detect the Si570 I2C bus and set up a systemd service to configure it at boot
- Install Flask and set up a systemd service to start the web server at boot

Once the script completes, the web UI is accessible at:

```
http://<board-ip>:5000
```

and the Jupyter interface remains available at:

```
http://<board-ip>:9090
```

## Use

### Web UI

The web UI is the recommended interface for controlling zPulse. Once the board is powered on, navigate to `http://<board-ip>:5000` from any browser on the same network. From there:

1. Select a bitstream from the dropdown and click **Load Bitstream** — the FPGA will be programmed automatically and the resolution set based on the bitstream filename (e.g. `zPulse_16.bit` sets 62.5 ps resolution)
2. Use the channel tabs to configure each channel independently: period, delay, pulses (width and start), drive controls (pre/post emphasis and amplitude), and enable/disable
3. Settings are preserved server-side and visible to any browser connecting to the same board

It is worth noting that this interface is more limited when compared to pure Pynq, as you don't get the full power of creating custom waveforms with Python.

### Jupyter notebook

The Jupyter interface is also available for those who prefer it. Navigate to `http://<board-ip>:9090/lab` (password: `xilinx`) and open `zPulse_GUI.ipynb`. Run the only cell present to launch the GUI. This GUI is much slower than the web UI, as it uses matplotlib library to do the plots and that takes some time.


### Locking to an external 10 MHz

As of the latest version, the system can be locked to an external 10 MHz clock using the CLK1_M2C_P port of the FMC HPC1 of the ZCU102 board (corresponding to the CLK_P pin on the [HiTech Global FMC module](https://www.hitechglobal.com/FMCModules/FMC_SMA_LVDS.htm)). 
Once the system detects that an external clock is being used, it automatically switches to using that clock to lock the Transceivers, thus locking the entire system. 

Regardless of wheter an external 10 MHz clock is provided, the CLK1_M2C_N port of the FMC HPC1 (corresponding to the CLK_N pin on the [HiTech Global FMC module](https://www.hitechglobal.com/FMCModules/FMC_SMA_LVDS.htm)) takes out a 10 MHz clock that is always locked to the Transceivers for locking external devices.

## Contribute

If you regenerate this design for a different FPGA board that is not the ZCU102, please let me know and it can be added within this same repository. Hog allows you to control separate projects (aimed for different boards for example), so it is easy to integrate new board designs.

Any bug or problem that you find please report it as an issue.
