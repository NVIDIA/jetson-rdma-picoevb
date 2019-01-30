##################################################################
# CHECK VIVADO VERSION
##################################################################

set scripts_vivado_version 2018.3
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
  create_project vivado-project vivado-project -part xc7a50tcsg325-2
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
}

##################################################################
# CHECK IPs
##################################################################

set bCheckIPs 1
set bCheckIPsPassed 1
if { $bCheckIPs == 1 } {
  set list_check_ips { xilinx.com:ip:axi_bram_ctrl:4.1 xilinx.com:ip:axi_gpio:2.0 xilinx.com:ip:blk_mem_gen:8.4 xilinx.com:ip:xdma:4.1 }
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
# CREATE IP axi_bram_ctrl_0
##################################################################

set axi_bram_ctrl axi_bram_ctrl_0
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 -module_name $axi_bram_ctrl

set_property -dict { 
  CONFIG.DATA_WIDTH {64}
  CONFIG.ID_WIDTH {2}
  CONFIG.SUPPORTS_NARROW_BURST {0}
  CONFIG.SINGLE_PORT_BRAM {1}
  CONFIG.ECC_TYPE {0}
  CONFIG.MEM_DEPTH {8192}
  CONFIG.READ_LATENCY {1}
  CONFIG.CLKIF.FREQ_HZ {125000000}
} [get_ips $axi_bram_ctrl]

##################################################################

##################################################################
# CREATE IP axi_gpio_0
##################################################################

set axi_gpio axi_gpio_0
create_ip -name axi_gpio -vendor xilinx.com -library ip -version 2.0 -module_name $axi_gpio

set_property -dict { 
  CONFIG.C_GPIO_WIDTH {3}
  CONFIG.C_GPIO2_WIDTH {4}
  CONFIG.C_IS_DUAL {1}
  CONFIG.C_ALL_INPUTS {0}
  CONFIG.C_TRI_DEFAULT_2 {0x0000000F}
  CONFIG.C_INTERRUPT_PRESENT {1}
  CONFIG.C_ALL_OUTPUTS {1}
} [get_ips $axi_gpio]

##################################################################

##################################################################
# CREATE IP blk_mem_gen_0
##################################################################

set blk_mem_gen blk_mem_gen_0
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $blk_mem_gen

set_property -dict { 
  CONFIG.Use_Byte_Write_Enable {true}
  CONFIG.Byte_Size {8}
  CONFIG.Write_Width_A {64}
  CONFIG.Write_Depth_A {8192}
  CONFIG.Read_Width_A {64}
  CONFIG.Write_Width_B {64}
  CONFIG.Read_Width_B {64}
  CONFIG.Register_PortA_Output_of_Memory_Primitives {false}
  CONFIG.Use_RSTA_Pin {true}
  CONFIG.Port_A_Clock {125}
  CONFIG.EN_SAFETY_CKT {true}
} [get_ips $blk_mem_gen]

##################################################################

##################################################################
# CREATE IP xdma_0
##################################################################

set xdma xdma_0
create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 -module_name $xdma

set_property -dict { 
  CONFIG.mode_selection {Basic}
  CONFIG.pl_link_cap_max_link_speed {5.0_GT/s}
  CONFIG.axisten_freq {125}
  CONFIG.vendor_id {10DE}
  CONFIG.pf0_device_id {0001}
  CONFIG.pf0_subsystem_vendor_id {10DE}
  CONFIG.pf0_subsystem_id {0001}
  CONFIG.pf0_base_class_menu {Memory_controller}
  CONFIG.pf0_class_code_base {05}
  CONFIG.pf0_sub_class_interface_menu {Other_memory_controller}
  CONFIG.pf0_class_code_sub {80}
  CONFIG.pf0_class_code_interface {00}
  CONFIG.pf0_class_code {058000}
  CONFIG.axilite_master_en {true}
  CONFIG.axilite_master_size {4}
  CONFIG.axilite_master_scale {Kilobytes}
  CONFIG.xdma_axilite_slave {false}
  CONFIG.plltype {QPLL1}
  CONFIG.pf0_msix_cap_table_bir {BAR_1}
  CONFIG.pf0_msix_cap_pba_bir {BAR_1}
  CONFIG.cfg_mgmt_if {false}
  CONFIG.axi_id_width {2}
  CONFIG.PF0_DEVICE_ID_mqdma {9021}
  CONFIG.PF2_DEVICE_ID_mqdma {9021}
  CONFIG.PF3_DEVICE_ID_mqdma {9021}
} [get_ips $xdma]

##################################################################

