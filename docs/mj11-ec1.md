# Gigabyte MJ11-EC1

A lot of information about this board can be found [here](https://forums.servethehome.com/index.php?threads/gigabyte-mj11-ec1-epyc-3151-mystery.41395/). This board comes from [G431-MM0](https://www.gigabyte.com/Enterprise/GPU-Server/G431-MM0-rev-100) mining rig. It is available for an affordable price in Europe at [Ram-König](https://en.ram-koenig.de/gigabyte-mj11-ec1-amd-epyc-3151-4x2-7-ghz-mini-itx-mainboard-atx-adapter-server-681).

This [blog](https://watchmysys.com/blog/2024/10/gigabyte-mj11-ec1-pcie-bifurcation/) has usefull tips on which adapters to buy, or not to buy, I can confirm I have successfully added a dual port 10 Gb SFP+ NIC using [this board](https://www.aliexpress.com/item/1005005811987501.html?spm=a2g0o.order_list.order_list_main.4.1a341802TjdCHO) and [this cable](https://www.aliexpress.com/item/1005005811987501.html?spm=a2g0o.order_list.order_list_main.4.1a341802TjdCHO)

[This](https://forums.servethehome.com/index.php?threads/gigabyte-mj11-ec1-epyc-3151-mystery.41395/post-444153) is also a good knowledge condensation in the Serve the Home thread.

[Manual](https://download.gigabyte.com/FileList/Manual/server_manual_MJ11-EC0_e_v10.pdf) for MJ11-EC0, not the same board, but close enough for reference.

- CPU: AMD EPYC Embedded 3151
- Frequency: 2,7 GHz / 2,9 GHz
- TDP: 45W
- CPU Cache: 16 MB
- Memory: RDIMM DDR4, UDIMM DDR4, UDIMM ECC DDR4 (Max 128 GB and 2666 MHz)
- Core Count: 4
- LAN: 1x 10/100/1000 management LAN, 2x 1Gbe RJ-45 LAN ports (Intel I210-AT)
- Video: VGA
- Form: Mini-ITX
- M.2: 1x M-key Gen3 x4 (supports NGFF-2280 cards)
- Headers: 1x 2x 2-pin 5VSB/PSON power connetor, 1x 2x 4-pin 12V power connector, 1x COM1 header, 1x CPU fan header, 1x Clear CMOS Jumper, 1x Front panel header, 1x IPMB connector, 1x M.2 slot, 1x PMBUS connector, 1x SlimSAS 4i connector (For additional 4 SATA drives), 1x SlimSAS 8i connector (For a expansion PCiE - NO BIFURCATION), 1x USB 3.0 header, 2x System fan headers

## Clear CMOS
It is recommended to clear CMOS before starting:

1. Unplug the board
2. Unplug the battery
3. Close the CMOS jumpper (besides the VGA connector)
4. Wait for a couple of minutes
5. Return the jumpper to the original position
6. Re-connect the battery

## BIOS Settings

The board was kept in its original BIOS F09, many users cross-flash F02 BIOS from its "sister's" board [MJ11-EC0](https://www.gigabyte.com/Enterprise/Server-Motherboard/MJ11-EC0-rev-12) seeking Bifurcation in the SlimSAS 8i connector (see the blog link above). To enable in a stable way for the board to boot with 4 dual rank RDIMMS, the clock speed has to be adjusted and limited to 1067 MHz, the UMC Common Options settings below are to enable stability with 4 dual rank RDIMMS.

```yaml
Advanced:
  CPU Configuration:
    SVM Mode: Enabled # Can be done via BMC
  PCI Subsystem Settings:
    SR-IOV Support: Enabled # Can be done via BMC
  AMD CBS:
    Zen Common Options:
      Core Performance Boost: Disabled
      Global C-state Control: Enabled
      Core/Thread Enablement: # Hyperthreading: Enabled
        Agree:
          SMTEN: Auto
    UMC Common Options:
      DDR4 Common Options:
        DRAM Timing Configuration: # Downclock Memory: 1067 MHz
          I Accept:
            Overclock: Enabled
            Memory Clock Speed: 1067 MHz
            Trcdrd: 10h Clk
            Trcdwr: 10h Clk
            Trp: 10h Clk
            ProcODT: 48 ohm #CPU-side memory bus termination
        Data Bus Configuration:
          Data Bus Configuration User Controls: Manual #on-die termination behavior
          RttNom: RZQ/7
          RttWr: Dynamic ODT Off
          RttPark: RZQ/2
    NBIO Common Options:
      NB Configuration:
        IOMMU: Enabled
      Determinism Slider: Power
Boot:
  Quiet Boot: Disabled # can be done via BMC
```

## Kernel parameters

Users reported that the board needs a PCIe kernel parameter to work as expected, the deployed Proxmox image uses:

```text
pcie_aspm=off
```

It fixes the known Zen1 EPYC PCIe ASPM instability without changing unrelated storage behavior.

It is not currently being used by me, but users reported other parameters if SATA hotplug or SATA disk detection behaves oddly:

```text
ahci.mobile_lpm_policy=1
```

If problems continue, use the fully conservative value:

```text
ahci.mobile_lpm_policy=0
```

## IO-Shield
Thanks to [rvbg](https://github.com/rvbg/mainboard-io-shields/tree/main/designs/gigabyte-mj11-ec1)

## Fan adapter
- [92mm Fan adapter](https://www.printables.com/model/772183-92mm-fan-adapter-for-gigabyte-mj11-ec1)
- [120mm Fan adapter](https://www.printables.com/model/648244-120mm-fan-adapter-for-gigabyte-mj11-ec1-and-mj11-e)

## Fan Profile
Apply the profile via [`make bmc-baseline`](../README.md) or import
[`mj11-quiet-fanprofile.json`](../infrastructure/ansible/files/bmc/mj11-quiet-fanprofile.json)
manually in the UI. Remember that the default curve considers a lot of GPU sensors, so the different policies might keep your fans at 40%.

BMC UI > Settings > Fan Profile > Import

Many users reported that SYS_FANs headers are not controllable, even tough you have the correct profile, so in my setup, I chose to chain 3 fans to the CPU header.

## BMC Firmware
The latest firmware available for AST2500 is currently [12.61.39](https://www.gigabyte.com/de/Enterprise/Server-Motherboard/MC12-LE0-rev-1x#Support-Firmware). Update can be done via BMC UI, some users reported BMC UI not to be accesible after updating and turning on Firewall settings. No problem to update for me.
