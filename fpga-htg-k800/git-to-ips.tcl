##################################################################
# CHECK VIVADO VERSION
##################################################################

set scripts_vivado_version 2018.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
  catch {common::send_msg_id "IPS_TCL-100" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_ip_tcl to create an updated script."}
  return 1
}

##################################################################
# START
##################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source git-to-ips.tcl
# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./vivado-project/vivado-project.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
  create_project vivado-project vivado-project -part xcku060-ffva1517-2-i
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
}

##################################################################
# CHECK IPs
##################################################################

set bCheckIPs 1
set bCheckIPsPassed 1
if { $bCheckIPs == 1 } {
  set list_check_ips { xilinx.com:ip:axi_clock_converter:2.1 xilinx.com:ip:axi_crossbar:2.1 xilinx.com:ip:axi_gpio:2.0 xilinx.com:ip:ddr4:2.2 xilinx.com:ip:proc_sys_reset:5.0 xilinx.com:ip:xdma:4.1 }
  set list_ips_missing ""
  common::send_msg_id "IPS_TCL-1001" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

  foreach ip_vlnv $list_check_ips {
  set ip_obj [get_ipdefs -all $ip_vlnv]
  if { $ip_obj eq "" } {
    lappend list_ips_missing $ip_vlnv
    }
  }

  if { $list_ips_missing ne "" } {
    catch {common::send_msg_id "IPS_TCL-105" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
    set bCheckIPsPassed 0
  }
}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "IPS_TCL-102" "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 1
}

##################################################################
# CREATE IP axi_clock_converter_0
##################################################################

set axi_clock_converter axi_clock_converter_0
create_ip -name axi_clock_converter -vendor xilinx.com -library ip -version 2.1 -module_name $axi_clock_converter

set_property -dict { 
  CONFIG.ADDR_WIDTH {31}
  CONFIG.DATA_WIDTH {256}
  CONFIG.ID_WIDTH {2}
  CONFIG.ACLK_ASYNC {1}
} [get_ips $axi_clock_converter]

generate_target {instantiation_template} [get_ips $axi_clock_converter]

##################################################################

##################################################################
# CREATE IP axi_crossbar_0
##################################################################

set axi_crossbar axi_crossbar_0
create_ip -name axi_crossbar -vendor xilinx.com -library ip -version 2.1 -module_name $axi_crossbar

set_property -dict { 
  CONFIG.ADDR_RANGES {1}
  CONFIG.NUM_MI {2}
  CONFIG.PROTOCOL {AXI4LITE}
  CONFIG.CONNECTIVITY_MODE {SASD}
  CONFIG.R_REGISTER {8}
  CONFIG.S00_WRITE_ACCEPTANCE {1}
  CONFIG.S01_WRITE_ACCEPTANCE {1}
  CONFIG.S02_WRITE_ACCEPTANCE {1}
  CONFIG.S03_WRITE_ACCEPTANCE {1}
  CONFIG.S04_WRITE_ACCEPTANCE {1}
  CONFIG.S05_WRITE_ACCEPTANCE {1}
  CONFIG.S06_WRITE_ACCEPTANCE {1}
  CONFIG.S07_WRITE_ACCEPTANCE {1}
  CONFIG.S08_WRITE_ACCEPTANCE {1}
  CONFIG.S09_WRITE_ACCEPTANCE {1}
  CONFIG.S10_WRITE_ACCEPTANCE {1}
  CONFIG.S11_WRITE_ACCEPTANCE {1}
  CONFIG.S12_WRITE_ACCEPTANCE {1}
  CONFIG.S13_WRITE_ACCEPTANCE {1}
  CONFIG.S14_WRITE_ACCEPTANCE {1}
  CONFIG.S15_WRITE_ACCEPTANCE {1}
  CONFIG.S00_READ_ACCEPTANCE {1}
  CONFIG.S01_READ_ACCEPTANCE {1}
  CONFIG.S02_READ_ACCEPTANCE {1}
  CONFIG.S03_READ_ACCEPTANCE {1}
  CONFIG.S04_READ_ACCEPTANCE {1}
  CONFIG.S05_READ_ACCEPTANCE {1}
  CONFIG.S06_READ_ACCEPTANCE {1}
  CONFIG.S07_READ_ACCEPTANCE {1}
  CONFIG.S08_READ_ACCEPTANCE {1}
  CONFIG.S09_READ_ACCEPTANCE {1}
  CONFIG.S10_READ_ACCEPTANCE {1}
  CONFIG.S11_READ_ACCEPTANCE {1}
  CONFIG.S12_READ_ACCEPTANCE {1}
  CONFIG.S13_READ_ACCEPTANCE {1}
  CONFIG.S14_READ_ACCEPTANCE {1}
  CONFIG.S15_READ_ACCEPTANCE {1}
  CONFIG.M00_WRITE_ISSUING {1}
  CONFIG.M01_WRITE_ISSUING {1}
  CONFIG.M02_WRITE_ISSUING {1}
  CONFIG.M03_WRITE_ISSUING {1}
  CONFIG.M04_WRITE_ISSUING {1}
  CONFIG.M05_WRITE_ISSUING {1}
  CONFIG.M06_WRITE_ISSUING {1}
  CONFIG.M07_WRITE_ISSUING {1}
  CONFIG.M08_WRITE_ISSUING {1}
  CONFIG.M09_WRITE_ISSUING {1}
  CONFIG.M10_WRITE_ISSUING {1}
  CONFIG.M11_WRITE_ISSUING {1}
  CONFIG.M12_WRITE_ISSUING {1}
  CONFIG.M13_WRITE_ISSUING {1}
  CONFIG.M14_WRITE_ISSUING {1}
  CONFIG.M15_WRITE_ISSUING {1}
  CONFIG.M00_READ_ISSUING {1}
  CONFIG.M01_READ_ISSUING {1}
  CONFIG.M02_READ_ISSUING {1}
  CONFIG.M03_READ_ISSUING {1}
  CONFIG.M04_READ_ISSUING {1}
  CONFIG.M05_READ_ISSUING {1}
  CONFIG.M06_READ_ISSUING {1}
  CONFIG.M07_READ_ISSUING {1}
  CONFIG.M08_READ_ISSUING {1}
  CONFIG.M09_READ_ISSUING {1}
  CONFIG.M10_READ_ISSUING {1}
  CONFIG.M11_READ_ISSUING {1}
  CONFIG.M12_READ_ISSUING {1}
  CONFIG.M13_READ_ISSUING {1}
  CONFIG.M14_READ_ISSUING {1}
  CONFIG.M15_READ_ISSUING {1}
  CONFIG.S00_SINGLE_THREAD {1}
  CONFIG.M00_SECURE {0}
  CONFIG.M01_A00_BASE_ADDR {0x0000000000001000}
} [get_ips $axi_crossbar]

generate_target {instantiation_template} [get_ips $axi_crossbar]

##################################################################

##################################################################
# CREATE IP axi_gpio_0
##################################################################

set axi_gpio axi_gpio_0
create_ip -name axi_gpio -vendor xilinx.com -library ip -version 2.0 -module_name $axi_gpio

set_property -dict { 
  CONFIG.C_GPIO_WIDTH {8}
  CONFIG.C_GPIO2_WIDTH {8}
  CONFIG.C_IS_DUAL {1}
  CONFIG.C_ALL_INPUTS {0}
  CONFIG.C_TRI_DEFAULT_2 {0xFFFFFFFF}
  CONFIG.C_ALL_INPUTS_2 {1}
  CONFIG.C_INTERRUPT_PRESENT {1}
  CONFIG.C_ALL_OUTPUTS {1}
} [get_ips $axi_gpio]

generate_target {instantiation_template} [get_ips $axi_gpio]

##################################################################

##################################################################
# CREATE IP axi_gpio_1
##################################################################

set axi_gpio axi_gpio_1
create_ip -name axi_gpio -vendor xilinx.com -library ip -version 2.0 -module_name $axi_gpio

set_property -dict { 
  CONFIG.C_GPIO_WIDTH {8}
  CONFIG.C_GPIO2_WIDTH {32}
  CONFIG.C_IS_DUAL {0}
  CONFIG.C_ALL_INPUTS {0}
  CONFIG.C_TRI_DEFAULT_2 {0xFFFFFFFF}
  CONFIG.C_ALL_INPUTS_2 {0}
  CONFIG.C_INTERRUPT_PRESENT {1}
  CONFIG.C_ALL_OUTPUTS {0}
} [get_ips $axi_gpio]

generate_target {instantiation_template} [get_ips $axi_gpio]

##################################################################

##################################################################
# CREATE IP ddr4_0
##################################################################

set ddr4 ddr4_0
create_ip -name ddr4 -vendor xilinx.com -library ip -version 2.2 -module_name $ddr4

set_property -dict { 
  CONFIG.C0.DDR4_InputClockPeriod {4998}
  CONFIG.C0.DDR4_MemoryPart {EDY4016AABG-DR-F}
  CONFIG.C0.DDR4_DataWidth {64}
  CONFIG.C0.DDR4_DataMask {DM_NO_DBI}
  CONFIG.C0.DDR4_Ecc {false}
  CONFIG.C0.DDR4_AxiSelection {true}
  CONFIG.C0.DDR4_CasLatency {16}
  CONFIG.C0.DDR4_AxiDataWidth {256}
  CONFIG.C0.DDR4_AxiAddressWidth {31}
  CONFIG.C0.DDR4_AxiIDWidth {2}
  CONFIG.Debug_Signal {Disable}
  CONFIG.C0.BANK_GROUP_WIDTH {1}
} [get_ips $ddr4]

generate_target {instantiation_template} [get_ips $ddr4]

##################################################################

##################################################################
# CREATE IP proc_sys_reset_0
##################################################################

set proc_sys_reset proc_sys_reset_0
create_ip -name proc_sys_reset -vendor xilinx.com -library ip -version 5.0 -module_name $proc_sys_reset

set_property -dict { 
  CONFIG.C_EXT_RESET_HIGH {1}
} [get_ips $proc_sys_reset]

generate_target {instantiation_template} [get_ips $proc_sys_reset]

##################################################################

##################################################################
# CREATE IP xdma_0
##################################################################

set xdma xdma_0
create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 -module_name $xdma

set_property -dict { 
  CONFIG.mode_selection {Advanced}
  CONFIG.pl_link_cap_max_link_width {X8}
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s}
  CONFIG.axi_data_width {256_bit}
  CONFIG.axisten_freq {250}
  CONFIG.en_ext_ch_gt_drp {false}
  CONFIG.sys_reset_polarity {ACTIVE_HIGH}
  CONFIG.vendor_id {10DE}
  CONFIG.pf0_device_id {0001}
  CONFIG.pf0_subsystem_vendor_id {10DE}
  CONFIG.pf0_subsystem_id {0002}
  CONFIG.pf0_base_class_menu {Memory_controller}
  CONFIG.pf0_class_code_base {05}
  CONFIG.pf0_sub_class_interface_menu {Other_memory_controller}
  CONFIG.pf0_class_code_sub {80}
  CONFIG.pf0_class_code_interface {00}
  CONFIG.pf0_class_code {058000}
  CONFIG.axilite_master_en {true}
  CONFIG.axilite_master_size {8}
  CONFIG.axilite_master_scale {Kilobytes}
  CONFIG.xdma_axilite_slave {false}
  CONFIG.select_quad {GTH_Quad_225}
  CONFIG.coreclk_freq {500}
  CONFIG.plltype {QPLL1}
  CONFIG.pf0_msix_cap_table_bir {BAR_1}
  CONFIG.pf0_msix_cap_pba_bir {BAR_1}
  CONFIG.cfg_mgmt_if {false}
  CONFIG.axi_id_width {2}
  CONFIG.PF0_DEVICE_ID_mqdma {9038}
  CONFIG.PF2_DEVICE_ID_mqdma {9038}
  CONFIG.PF3_DEVICE_ID_mqdma {9038}
} [get_ips $xdma]

generate_target {instantiation_template} [get_ips $xdma]

##################################################################

