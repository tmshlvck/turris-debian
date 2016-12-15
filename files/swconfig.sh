#!/bin/bash

swconfig dev switch0 set reset
swconfig dev switch0 vlan 1 set ports "0 1 2 3 5"
swconfig dev switch0 vlan 2 set ports "4 6"
swconfig dev switch0 set enable_vlan 1
swconfig dev switch0 set apply 1

exit 0

