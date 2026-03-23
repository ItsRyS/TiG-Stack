#!/usr/bin/env bash
# lib/oids/if_mib.sh — IF-MIB interface statistics (switch/router/firewall/server)

oids_if_mib() { cat <<'TOML'

  ## ── Interfaces — 64-bit (IF-MIB::ifXTable, RFC 2233) ─────────────────
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
      name = "if_type"
      oid  = "IF-MIB::ifType"
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
      name = "if_in_ucast_pkts"
      oid  = "IF-MIB::ifHCInUcastPkts"
    [[inputs.snmp.table.field]]
      name = "if_out_ucast_pkts"
      oid  = "IF-MIB::ifHCOutUcastPkts"
    [[inputs.snmp.table.field]]
      name = "if_in_multicast_pkts"
      oid  = "IF-MIB::ifHCInMulticastPkts"
    [[inputs.snmp.table.field]]
      name = "if_out_multicast_pkts"
      oid  = "IF-MIB::ifHCOutMulticastPkts"
    [[inputs.snmp.table.field]]
      name = "if_in_broadcast_pkts"
      oid  = "IF-MIB::ifHCInBroadcastPkts"
    [[inputs.snmp.table.field]]
      name = "if_out_broadcast_pkts"
      oid  = "IF-MIB::ifHCOutBroadcastPkts"
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
TOML
}