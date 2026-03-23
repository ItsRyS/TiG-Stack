#!/usr/bin/env bash
# lib/oids/system.sh — SNMPv2-MIB system info (all device types)

oids_system_info() { cat <<'TOML'

  ## ── System Info (SNMPv2-MIB) ──────────────────────────────────────────
  [[inputs.snmp.field]]
    name   = "sys_name"
    oid    = "SNMPv2-MIB::sysName.0"
    is_tag = true
  [[inputs.snmp.field]]
    name = "sys_descr"
    oid  = "SNMPv2-MIB::sysDescr.0"
  [[inputs.snmp.field]]
    name = "sys_uptime"
    oid  = "SNMPv2-MIB::sysUpTime.0"
  [[inputs.snmp.field]]
    name = "sys_contact"
    oid  = "SNMPv2-MIB::sysContact.0"
  [[inputs.snmp.field]]
    name = "sys_location"
    oid  = "SNMPv2-MIB::sysLocation.0"
TOML
}