#=============================================================================
# snake_k7.xdc - Snake Game Constraints for Kintex-7 FPGA Board
#=============================================================================

#---- Clock (100MHz) ----
create_clock -name clk100MHZ -period 10.0 [get_ports clk]
set_property PACKAGE_PIN AC18 [get_ports clk]
set_property IOSTANDARD LVCMOS18 [get_ports clk]

#---- Reset (active-low button at W13) ----
set_property PACKAGE_PIN W13 [get_ports rstn]
set_property IOSTANDARD LVCMOS18 [get_ports rstn]
set_property PULLUP TRUE [get_ports rstn]

#---- Direction Buttons (active-low: pressed = GND) ----
# BTN[0] = UP
set_property PACKAGE_PIN W14 [get_ports {BTN[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {BTN[0]}]
set_property PULLUP TRUE [get_ports {BTN[0]}]

# BTN[1] = DOWN
set_property PACKAGE_PIN V14 [get_ports {BTN[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {BTN[1]}]
set_property PULLUP TRUE [get_ports {BTN[1]}]

# BTN[2] = LEFT
set_property PACKAGE_PIN V19 [get_ports {BTN[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {BTN[2]}]
set_property PULLUP TRUE [get_ports {BTN[2]}]

# BTN[3] = RIGHT
set_property PACKAGE_PIN V18 [get_ports {BTN[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {BTN[3]}]
set_property PULLUP TRUE [get_ports {BTN[3]}]

# BTNX4 = START (center button)
set_property PACKAGE_PIN W16 [get_ports BTNX4]
set_property IOSTANDARD LVCMOS18 [get_ports BTNX4]
set_property PULLUP TRUE [get_ports BTNX4]

#---- PS/2 Keyboard ----
set_property PACKAGE_PIN N18 [get_ports ps2_clk]
set_property PACKAGE_PIN M19 [get_ports ps2_data]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_clk]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_data]

#---- VGA Output (4:4:4) ----
set_property PACKAGE_PIN N21 [get_ports {r[0]}]
set_property PACKAGE_PIN N22 [get_ports {r[1]}]
set_property PACKAGE_PIN R21 [get_ports {r[2]}]
set_property PACKAGE_PIN P21 [get_ports {r[3]}]
set_property PACKAGE_PIN R22 [get_ports {g[0]}]
set_property PACKAGE_PIN R23 [get_ports {g[1]}]
set_property PACKAGE_PIN T24 [get_ports {g[2]}]
set_property PACKAGE_PIN T25 [get_ports {g[3]}]
set_property PACKAGE_PIN T20 [get_ports {b[0]}]
set_property PACKAGE_PIN R20 [get_ports {b[1]}]
set_property PACKAGE_PIN T22 [get_ports {b[2]}]
set_property PACKAGE_PIN T23 [get_ports {b[3]}]
set_property PACKAGE_PIN M22 [get_ports hs]
set_property PACKAGE_PIN M21 [get_ports vs]

set_property IOSTANDARD LVCMOS33 [get_ports {r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports hs]
set_property IOSTANDARD LVCMOS33 [get_ports vs]

set_property SLEW FAST [get_ports {r[0]}]
set_property SLEW FAST [get_ports {r[1]}]
set_property SLEW FAST [get_ports {r[2]}]
set_property SLEW FAST [get_ports {r[3]}]
set_property SLEW FAST [get_ports {g[0]}]
set_property SLEW FAST [get_ports {g[1]}]
set_property SLEW FAST [get_ports {g[2]}]
set_property SLEW FAST [get_ports {g[3]}]
set_property SLEW FAST [get_ports {b[0]}]
set_property SLEW FAST [get_ports {b[1]}]
set_property SLEW FAST [get_ports {b[2]}]
set_property SLEW FAST [get_ports {b[3]}]
set_property SLEW FAST [get_ports hs]
set_property SLEW FAST [get_ports vs]

#---- LEDs ----
set_property PACKAGE_PIN W23 [get_ports {LED[0]}]
set_property PACKAGE_PIN AB26 [get_ports {LED[1]}]
set_property PACKAGE_PIN Y25 [get_ports {LED[2]}]
set_property PACKAGE_PIN AA23 [get_ports {LED[3]}]
set_property PACKAGE_PIN Y23 [get_ports {LED[4]}]
set_property PACKAGE_PIN Y22 [get_ports {LED[5]}]
set_property PACKAGE_PIN AE21 [get_ports {LED[6]}]
set_property PACKAGE_PIN AF24 [get_ports {LED[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[7]}]

#---- Buzzer (piezo speaker) ----
# TODO: assign the correct pin for your board's buzzer
set_property PACKAGE_PIN T19  [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]
set_property SLEW FAST [get_ports buzzer]

#---- 7-Segment Display ----
set_property PACKAGE_PIN AB22 [get_ports {SEGMENT[0]}]
set_property PACKAGE_PIN AD24 [get_ports {SEGMENT[1]}]
set_property PACKAGE_PIN AD23 [get_ports {SEGMENT[2]}]
set_property PACKAGE_PIN Y21 [get_ports {SEGMENT[3]}]
set_property PACKAGE_PIN W20 [get_ports {SEGMENT[4]}]
set_property PACKAGE_PIN AC24 [get_ports {SEGMENT[5]}]
set_property PACKAGE_PIN AC23 [get_ports {SEGMENT[6]}]
set_property PACKAGE_PIN AA22 [get_ports {SEGMENT[7]}]
set_property PACKAGE_PIN AD21 [get_ports {AN[0]}]
set_property PACKAGE_PIN AC21 [get_ports {AN[1]}]
set_property PACKAGE_PIN AB21 [get_ports {AN[2]}]
set_property PACKAGE_PIN AC22 [get_ports {AN[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SEGMENT[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AN[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AN[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AN[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AN[3]}]
