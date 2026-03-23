#!/usr/bin/env bash
# =============================================================================
# lib/oids/esxi.sh — VMware ESXi SNMP OIDs
#
# MIB Strategy:
#   Standard MIBs  : SNMPv2-MIB, HOST-RESOURCES-MIB, IF-MIB (ใช้ชื่อได้เลย)
#   VMware MIBs    : ใช้ numeric OIDs เพราะ VMware MIB files ต้องดาวน์โหลดแยก
#
# VMware OID root  : 1.3.6.1.4.1.6876  (enterprises.vmware)
#   vmwSystem      : .1.1  — ESXi version, build
#   vmwResources   : .3    — CPU/Memory usage (host level)
#   vmwVmInfo      : .2.1  — Per-VM info table (ใช้เป็น field ไม่ใช่ table)
#
# Enable SNMP on ESXi:
#   esxcli system snmp set -c <community> -e true
#   esxcli system snmp set --version v3 (for SNMPv3)
#
# Firewall (allow monitoring host):
#   esxcli network firewall ruleset set --ruleset-id snmp --allowed-all false
#   esxcli network firewall ruleset allowedip add --ruleset-id snmp --ip-address <IP>
#   esxcli network firewall ruleset set --ruleset-id snmp --enabled true
# =============================================================================

oids_esxi() { cat <<'TOML'

  ## ── ESXi Version & Build (VMWARE-SYSTEM-MIB — numeric OIDs) ──────────
  # vmwProdName  = 1.3.6.1.4.1.6876.1.1.0
  # vmwProdVersion = 1.3.6.1.4.1.6876.1.2.0
  # vmwProdBuild = 1.3.6.1.4.1.6876.1.4.0
  [[inputs.snmp.field]]
    name = "esxi_product_name"
    oid  = "1.3.6.1.4.1.6876.1.1.0"
  [[inputs.snmp.field]]
    name = "esxi_version"
    oid  = "1.3.6.1.4.1.6876.1.2.0"
  [[inputs.snmp.field]]
    name = "esxi_build"
    oid  = "1.3.6.1.4.1.6876.1.4.0"

  ## ── Host Memory (HOST-RESOURCES-MIB) ─────────────────────────────────
  # hrMemorySize = total RAM in KB
  [[inputs.snmp.field]]
    name = "hr_memory_size_kb"
    oid  = "HOST-RESOURCES-MIB::hrMemorySize.0"

  ## ── Host CPU via HOST-RESOURCES-MIB (hrProcessorTable) ───────────────
  [[inputs.snmp.table]]
    name         = "hr_processor"
    inherit_tags = ["device_name", "device_type", "device_ip"]
    oid          = "HOST-RESOURCES-MIB::hrProcessorTable"
    [[inputs.snmp.table.field]]
      name = "processor_load"
      oid  = "HOST-RESOURCES-MIB::hrProcessorLoad"

  ## ── Host Storage (HOST-RESOURCES-MIB) ────────────────────────────────
  [[inputs.snmp.table]]
    name         = "hr_storage"
    inherit_tags = ["device_name", "device_type", "device_ip"]
    oid          = "HOST-RESOURCES-MIB::hrStorageTable"
    [[inputs.snmp.table.field]]
      name   = "storage_descr"
      oid    = "HOST-RESOURCES-MIB::hrStorageDescr"
      is_tag = true
    [[inputs.snmp.table.field]]
      name = "storage_allocation_units"
      oid  = "HOST-RESOURCES-MIB::hrStorageAllocationUnits"
    [[inputs.snmp.table.field]]
      name = "storage_size"
      oid  = "HOST-RESOURCES-MIB::hrStorageSize"
    [[inputs.snmp.table.field]]
      name = "storage_used"
      oid  = "HOST-RESOURCES-MIB::hrStorageUsed"

  ## ── Host Network Interfaces (IF-MIB) ─────────────────────────────────
  # ESXi รายงาน physical vmnic + virtual vmk interfaces
  [[inputs.snmp.table]]
    name         = "interface"
    inherit_tags = ["device_name", "device_type", "device_ip", "sys_name"]
    oid          = "IF-MIB::ifXTable"
    [[inputs.snmp.table.field]]
      name   = "if_name"
      oid    = "IF-MIB::ifName"
      is_tag = true
    [[inputs.snmp.table.field]]
      name   = "if_alias"
      oid    = "IF-MIB::ifAlias"
      is_tag = true
    [[inputs.snmp.table.field]]
      name = "if_high_speed"
      oid  = "IF-MIB::ifHighSpeed"
    [[inputs.snmp.table.field]]
      name = "if_admin_status"
      oid  = "IF-MIB::ifAdminStatus"
    [[inputs.snmp.table.field]]
      name = "if_oper_status"
      oid  = "IF-MIB::ifOperStatus"
    [[inputs.snmp.table.field]]
      name = "if_in_octets"
      oid  = "IF-MIB::ifHCInOctets"
    [[inputs.snmp.table.field]]
      name = "if_out_octets"
      oid  = "IF-MIB::ifHCOutOctets"
    [[inputs.snmp.table.field]]
      name = "if_in_errors"
      oid  = "IF-MIB::ifInErrors"
    [[inputs.snmp.table.field]]
      name = "if_out_errors"
      oid  = "IF-MIB::ifOutErrors"
    [[inputs.snmp.table.field]]
      name = "if_in_discards"
      oid  = "IF-MIB::ifInDiscards"
    [[inputs.snmp.table.field]]
      name = "if_out_discards"
      oid  = "IF-MIB::ifOutDiscards"

  ## ── VM Count & State (VMWARE-VMINFO-MIB — numeric OIDs) ──────────────
  # vmwVmTable ใช้เป็น table ไม่ได้กับ Telegraf — ใช้ individual fields แทน
  # vmwNumVMs = จำนวน VM ทั้งหมดที่ host รู้จัก
  # 1.3.6.1.4.1.6876.2.1 = vmwVmTable (walk เพื่อ count ได้)
  [[inputs.snmp.field]]
    name = "vm_count"
    oid  = "1.3.6.1.4.1.6876.1.6.0"
  # 1.3.6.1.4.1.6876.1.6.0 = vmwNumVMs

  ## ── Host-level Resource Usage (VMWARE-RESOURCES-MIB — numeric OIDs) ──
  # vmwHostCpuUsed  = 1.3.6.1.4.1.6876.3.2.1.0  (MHz used by all VMs)
  # vmwHostCpuTotal = 1.3.6.1.4.1.6876.3.2.2.0  (MHz total)
  # vmwHostMemUsed  = 1.3.6.1.4.1.6876.3.3.1.0  (KB used)
  # vmwHostMemTotal = 1.3.6.1.4.1.6876.3.3.2.0  (KB total)
  [[inputs.snmp.field]]
    name = "host_cpu_used_mhz"
    oid  = "1.3.6.1.4.1.6876.3.2.1.0"
  [[inputs.snmp.field]]
    name = "host_cpu_total_mhz"
    oid  = "1.3.6.1.4.1.6876.3.2.2.0"
  [[inputs.snmp.field]]
    name = "host_mem_used_kb"
    oid  = "1.3.6.1.4.1.6876.3.3.1.0"
  [[inputs.snmp.field]]
    name = "host_mem_total_kb"
    oid  = "1.3.6.1.4.1.6876.3.3.2.0"
TOML
}