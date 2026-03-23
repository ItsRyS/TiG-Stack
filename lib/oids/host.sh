#!/usr/bin/env bash
# lib/oids/host.sh — HOST-RESOURCES-MIB + UCD-SNMP-MIB (server/envmonitor)

oids_host_resources() { cat <<'TOML'

  ## ── CPU / Storage / System (HOST-RESOURCES-MIB) ──────────────────────
  [[inputs.snmp.table]]
    name         = "hr_processor"
    inherit_tags = ["device_name", "device_type", "device_ip"]
    oid          = "HOST-RESOURCES-MIB::hrProcessorTable"
    [[inputs.snmp.table.field]]
      name = "processor_load"
      oid  = "HOST-RESOURCES-MIB::hrProcessorLoad"

  [[inputs.snmp.table]]
    name         = "hr_storage"
    inherit_tags = ["device_name", "device_type", "device_ip"]
    oid          = "HOST-RESOURCES-MIB::hrStorageTable"
    [[inputs.snmp.table.field]]
      name   = "storage_descr"
      oid    = "HOST-RESOURCES-MIB::hrStorageDescr"
      is_tag = true
    [[inputs.snmp.table.field]]
      name = "storage_type"
      oid  = "HOST-RESOURCES-MIB::hrStorageType"
    [[inputs.snmp.table.field]]
      name = "storage_allocation_units"
      oid  = "HOST-RESOURCES-MIB::hrStorageAllocationUnits"
    [[inputs.snmp.table.field]]
      name = "storage_size"
      oid  = "HOST-RESOURCES-MIB::hrStorageSize"
    [[inputs.snmp.table.field]]
      name = "storage_used"
      oid  = "HOST-RESOURCES-MIB::hrStorageUsed"

  [[inputs.snmp.field]]
    name = "hr_system_processes"
    oid  = "HOST-RESOURCES-MIB::hrSystemProcesses.0"
  [[inputs.snmp.field]]
    name = "hr_system_num_users"
    oid  = "HOST-RESOURCES-MIB::hrSystemNumUsers.0"
  [[inputs.snmp.field]]
    name = "hr_system_uptime"
    oid  = "HOST-RESOURCES-MIB::hrSystemUptime.0"
TOML
}

oids_ucd_snmp() { cat <<'TOML'

  ## ── Load Avg / Memory / DiskIO (UCD-SNMP-MIB) ────────────────────────
  [[inputs.snmp.field]]
    name = "load_avg_1min"
    oid  = "UCD-SNMP-MIB::laLoad.1"
  [[inputs.snmp.field]]
    name = "load_avg_5min"
    oid  = "UCD-SNMP-MIB::laLoad.2"
  [[inputs.snmp.field]]
    name = "load_avg_15min"
    oid  = "UCD-SNMP-MIB::laLoad.3"
  [[inputs.snmp.field]]
    name = "mem_total_real"
    oid  = "UCD-SNMP-MIB::memTotalReal.0"
  [[inputs.snmp.field]]
    name = "mem_avail_real"
    oid  = "UCD-SNMP-MIB::memAvailReal.0"
  [[inputs.snmp.field]]
    name = "mem_total_free"
    oid  = "UCD-SNMP-MIB::memTotalFree.0"
  [[inputs.snmp.field]]
    name = "mem_buffer"
    oid  = "UCD-SNMP-MIB::memBuffer.0"
  [[inputs.snmp.field]]
    name = "mem_cached"
    oid  = "UCD-SNMP-MIB::memCached.0"

  [[inputs.snmp.table]]
    name         = "diskio"
    inherit_tags = ["device_name", "device_type", "device_ip"]
    oid          = "UCD-DISKIO-MIB::diskIOTable"
    [[inputs.snmp.table.field]]
      name   = "disk_device"
      oid    = "UCD-DISKIO-MIB::diskIODevice"
      is_tag = true
    [[inputs.snmp.table.field]]
      name = "disk_read_bytes"
      oid  = "UCD-DISKIO-MIB::diskIONReadX"
    [[inputs.snmp.table.field]]
      name = "disk_write_bytes"
      oid  = "UCD-DISKIO-MIB::diskIONWrittenX"
    [[inputs.snmp.table.field]]
      name = "disk_read_ops"
      oid  = "UCD-DISKIO-MIB::diskIOReads"
    [[inputs.snmp.table.field]]
      name = "disk_write_ops"
      oid  = "UCD-DISKIO-MIB::diskIOWrites"
TOML
}