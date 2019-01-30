# Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
# Derived from prog-flash.tcl in PicoEVB sample project

# Connect to the HW
open_hw
for {set i 0} {$i < 10} {incr i} {
    if ([catch {
        # These commands are very unreliable, so retry them until it works.
        connect_hw_server
        open_hw_target -xvc_url localhost:2542
    } errmsg]) {
        puts "Connection attempt $i failed\n"
        if {$i != 9} {
            puts "Retrying connection attempt\n";
            exec sleep 1
        }
        catch {
            close_hw_target
        } errmsg
        catch {
            disconnect_hw_server
        } errmsg
    } else {
        puts "Connection OK; continuing\n"
        break
    }
}
if {$i == 10} {
    puts "Too many connection attempts; exiting\n"
    exit 1
}

# Add flash part, s25fl132k; default to erase and program (no verify)
create_hw_cfgmem -hw_device [lindex [get_hw_devices xc7a50t_0] 0] [lindex [get_cfgmem_parts {s25fl132k-spi-x1_x2_x4}] 0]
set_property PROGRAM.BLANK_CHECK  0 [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
set_property PROGRAM.ERASE  1 [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
set_property PROGRAM.VERIFY  0 [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
set_property PROGRAM.CHECKSUM  0 [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
refresh_hw_device [lindex [get_hw_devices xc7a50t_0] 0]
set_property PROGRAM.ADDRESS_RANGE  {use_file} [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
set_property PROGRAM.FILES [list "picoevb.mcs"] [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
set_property PROGRAM.PRM_FILE {} [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]

# Program the fabric with the flash loader
startgroup
if {![string equal \
        [get_property PROGRAM.HW_CFGMEM_TYPE [lindex [get_hw_devices xc7a50t_0] 0]] \
        [get_property MEM_TYPE [get_property CFGMEM_PART [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]]]] } {
    create_hw_bitstream -hw_device [lindex [get_hw_devices xc7a50t_0] 0] [get_property PROGRAM.HW_CFGMEM_BITFILE [lindex [get_hw_devices xc7a50t_0] 0]]
    program_hw_devices [lindex [get_hw_devices xc7a50t_0] 0]
}

# Program the flash
program_hw_cfgmem -hw_cfgmem [get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a50t_0] 0]]

# Clean up and disconnect
close_hw_target
disconnect_hw_server
close_hw
