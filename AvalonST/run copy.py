#!/usr/bin/env python3

import os
from pathlib import Path
from vunit import VUnit
from vunit.ui.testbench import TestBench
import importlib.util
import sys
from types import ModuleType


class ModelExecutor:
    _path: Path
    _tb: TestBench
    _module: ModuleType

    def __init__(self, path: Path, tb: TestBench):
        self._path = path
        self._tb = tb
        self._load_model_module()

    def _load_model_module(self):
        # the name of the file af tb_xyz is xyz_model.py
        file_name = f"{self._tb.name[3:]}_model.py"
        spec = importlib.util.spec_from_file_location(self._tb.name,
                                                      self._path / file_name)
        if not spec or not spec.loader:
            print(f"Error while loading file {self._path}")
            exit(1)
        self._module = importlib.util.module_from_spec(spec)
        sys.modules[self._tb.name] = self._module
        spec.loader.exec_module(self._module)

        self._module.setup(self._tb)

    def pre_config(self, output_path: str) -> bool:
        return self._module.config(self._tb, output_path)


if os.getenv("VUNIT_SIMULATOR") is None:
    # check nvc availability
    status = os.system("nvc --version")
    if status == 0:
        os.environ["VUNIT_SIMULATOR"] = "nvc"
    else:
        raise ValueError("VUNIT_SIMULATOR not set!")

# some path defines
SUBMODULES = Path(__file__).resolve().parents[3] / ".submodules"
UVVM_PATH = SUBMODULES / "uvvm"
GUI_DO_PATH = Path(__file__).resolve().parent / "gui.do"
SRC_PATH = Path(__file__).resolve().parents[1] / "prjRFSoC"

# create vunit object
VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_verification_components()
# VU.add_json4vhdl()

# uvvm libs to use
UVVM_LIBS = [
    "uvvm_util",
    "uvvm_vvc_framework",
    #"bitvis_vip_axilite",
    #"bitvis_vip_axistream",
    "bitvis_vip_clock_generator",
    "bitvis_vip_scoreboard",
    # "bitvis_irqc",
    # "bitvis_uart",
    # "bitvis_vip_avalon_mm",
    # "bitvis_vip_avalon_st",
    # "bitvis_vip_axi",
    # "bitvis_vip_error_injection",
    # "bitvis_vip_ethernet",
    # "bitvis_vip_gmii",
    # "bitvis_vip_gpio",
    # "bitvis_vip_hvvc_to_vvc_bridge",
    # "bitvis_vip_i2c",
    # "bitvis_vip_rgmii",
    #"bitvis_vip_sbi",
    # "bitvis_vip_spec_cov",
    #"bitvis_vip_spi",
    # "bitvis_vip_uart",
    # "bitvis_vip_wishbone"
]

# add uvvm libs
if os.getenv("VUNIT_SIMULATOR") != "nvc":
    for lib_name in UVVM_LIBS:
        uvvm_lib = VU.add_library(lib_name)
        # get lines from file, skip the first line as it just contains a comment
        files = open(UVVM_PATH / lib_name / "script" / "compile_order.txt",
                     "r").readlines()
        for file in files:
            if file.startswith(".."):
                # add all the files to the created library
                # remove \n from the end of the path as vunit cannot deal with it
                file = str(
                    (UVVM_PATH / lib_name / "script" / file).resolve())[:-1]
                uvvm_lib.add_source_files(file)
                uvvm_lib.add_compile_option("ghdl.a_flags", ["-frelaxed"])

# add our own Json4VHDL
json_lib = VU.add_library("json")
json_lib.add_source_files(SUBMODULES / "JSON-for-VHDL" / "src" / "*.vhdl")

# add source files
# only add packet generator for now
lib = VU.add_library("lib")
lib.add_source_files(SRC_PATH / "grpPacketGeneration" / "axis_packet_generator" / "*" / "*.vhd")
lib.add_source_files(SRC_PATH / "grpSignalProcessing" / "polyphase_decimation" / "**" / "*.vhd")
lib.add_source_files(SRC_PATH / "grpSignalProcessing" / "sim_signal_processing" / "**" / "*.vhd")
lib.add_source_files(SRC_PATH / "grpSignalProcessing" / "mixer" / "**" / "*.vhd")
lib.add_source_files(SRC_PATH / "grpUtility" / "**" / "*.vhd")
# lib.add_source_files(SRC_PATH / "grpPacketizer" / "*" / "*" / "*.vhd")
# lib.add_source_files(SRC_PATH / "grpSpi" / "*" / "*" / "*.vhd")


lib.add_source_files(SRC_PATH / "grpSignalProcessing" /
                     "iq_ramp_generator" / "**" / "*.vhd")

lib.add_compile_option("ghdl.a_flags", ["-frelaxed", "-fsynopsys"])

VU.set_sim_option("nvc.global_flags", ["-M", "32M"])
VU.set_sim_option("nvc.heap_size", "2048m")
VU.set_sim_option("ghdl.sim_flags", ["--max-stack-alloc=1024"])

for tb in lib.get_test_benches():
    tb.set_sim_option("modelsim.init_file.gui", str(GUI_DO_PATH))
    tb.set_sim_option("ghdl.elab_flags", ["-frelaxed"])
    try:
        tb_folder = (
            Path(os.environ["PWD"]) /
            tb.library.get_source_file(f"*{tb.name}-bhv*").name).parents[1]
    except:
        continue
    sim_folder: Path = tb_folder / "sim"
    if (sim_folder).exists():
        sys.path.append(str(sim_folder.absolute()))
        model_exec = ModelExecutor(sim_folder, tb)
        tb.set_pre_config(model_exec.pre_config)


VU.main()
