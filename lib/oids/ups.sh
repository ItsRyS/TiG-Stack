#!/usr/bin/env bash
# lib/oids/ups.sh — UPS-MIB RFC 1628 (numeric OIDs, no MIB file needed)

oids_ups_mib() { cat <<'TOML'

  ## ── UPS-MIB RFC 1628 (numeric OIDs) ──────────────────────────────────
  [[inputs.snmp.field]]
    name = "ups_manufacturer"
    oid  = "1.3.6.1.2.1.33.1.1.1.0"
  [[inputs.snmp.field]]
    name = "ups_model"
    oid  = "1.3.6.1.2.1.33.1.1.2.0"
  [[inputs.snmp.field]]
    name = "ups_firmware"
    oid  = "1.3.6.1.2.1.33.1.1.4.0"

  # Battery (1=unknown 2=normal 3=low 4=depleted)
  [[inputs.snmp.field]]
    name = "ups_battery_status"
    oid  = "1.3.6.1.2.1.33.1.2.1.0"
  [[inputs.snmp.field]]
    name = "ups_seconds_on_battery"
    oid  = "1.3.6.1.2.1.33.1.2.2.0"
  [[inputs.snmp.field]]
    name = "ups_est_minutes_remaining"
    oid  = "1.3.6.1.2.1.33.1.2.3.0"
  [[inputs.snmp.field]]
    name = "ups_est_charge_remaining"
    oid  = "1.3.6.1.2.1.33.1.2.4.0"
  [[inputs.snmp.field]]
    name = "ups_battery_voltage"
    oid  = "1.3.6.1.2.1.33.1.2.5.0"
  [[inputs.snmp.field]]
    name = "ups_battery_current"
    oid  = "1.3.6.1.2.1.33.1.2.6.0"
  [[inputs.snmp.field]]
    name = "ups_battery_temperature"
    oid  = "1.3.6.1.2.1.33.1.2.7.0"

  # Input lines
  [[inputs.snmp.table]]
    name         = "ups_input"
    inherit_tags = ["device_name", "device_type", "device_ip"]
    oid          = "1.3.6.1.2.1.33.1.3.3"
    [[inputs.snmp.table.field]]
      name = "ups_input_frequency"
      oid  = "1.3.6.1.2.1.33.1.3.3.1.2"
    [[inputs.snmp.table.field]]
      name = "ups_input_voltage"
      oid  = "1.3.6.1.2.1.33.1.3.3.1.3"
    [[inputs.snmp.table.field]]
      name = "ups_input_current"
      oid  = "1.3.6.1.2.1.33.1.3.3.1.4"
    [[inputs.snmp.table.field]]
      name = "ups_input_true_power"
      oid  = "1.3.6.1.2.1.33.1.3.3.1.5"

  # Output (1=other 2=none 3=normal 4=bypass 5=battery 6=booster 7=reducer)
  [[inputs.snmp.field]]
    name = "ups_output_source"
    oid  = "1.3.6.1.2.1.33.1.4.1.0"
  [[inputs.snmp.field]]
    name = "ups_output_frequency"
    oid  = "1.3.6.1.2.1.33.1.4.2.0"
  [[inputs.snmp.field]]
    name = "ups_output_num_lines"
    oid  = "1.3.6.1.2.1.33.1.4.3.0"
  [[inputs.snmp.table]]
    name         = "ups_output"
    inherit_tags = ["device_name", "device_type", "device_ip"]
    oid          = "1.3.6.1.2.1.33.1.4.4"
    [[inputs.snmp.table.field]]
      name = "ups_output_voltage"
      oid  = "1.3.6.1.2.1.33.1.4.4.1.2"
    [[inputs.snmp.table.field]]
      name = "ups_output_current"
      oid  = "1.3.6.1.2.1.33.1.4.4.1.3"
    [[inputs.snmp.table.field]]
      name = "ups_output_power"
      oid  = "1.3.6.1.2.1.33.1.4.4.1.4"
    [[inputs.snmp.table.field]]
      name = "ups_output_percent_load"
      oid  = "1.3.6.1.2.1.33.1.4.4.1.5"

  # Alarms
  [[inputs.snmp.field]]
    name = "ups_alarms_present"
    oid  = "1.3.6.1.2.1.33.1.6.1.0"
TOML
}