# Blackjack Plug-N-Play on FPGA

## Overview
A complete multiplayer Blackjack game system implemented on FPGA (Spartan-3E) that supports up to 4 players playing simultaneously against a dealer. The system uses UART communication for player modules and features a 7-segment display for dealer information.

## System Architecture

### Components
- **Dealer Module** (`Dealer_main.vhdl`) - Main game controller
- **Player Modules** (`Player_main.vhdl`) - Individual player controllers (up to 4)
- **UART Communication** (`uart_tx.vhdl`, `uart_rx.vhdl`) - Serial communication between modules
- **7-Segment Display Driver** (`7segment.vhdl`) - Display driver for game status
- **Random Number Generator** (`rng_module.vhdl`) - Card drawing mechanism using LFSR

## Features

### Game Mechanics
- **Standard Blackjack Rules**: Hit, Stand, and Double Down options
- **Multiplayer Support**: Up to 4 players can play simultaneously
- **Betting System**: Players start with 4 chips and can bet/double
- **Blackjack Detection**: Automatic detection and payout (1.5x)
- **Bust Detection**: Automatic loss when exceeding 21
- **Push Handling**: Tie results return the bet

### Hardware Features
- **Plug-and-Play**: Hot-pluggable player modules via KDET (Key Detection)
- **Visual Feedback**: 7-segment display shows game state and scores
- **LED Indicators**: Show remaining chips for each player
- **Audio Feedback**: Buzzer signals for dealer actions and player turns

## Pin Configuration

### Dealer Module Ports
```vhdl
i_clk_20mhz  : Clock input (20 MHz)
i_pb1_start  : Start game button
i_kdet_p1-4  : Player detection signals (active high)
i_uart_rx_p1-4 : UART receive from players
o_uart_tx_p1-4 : UART transmit to players
o_anodes     : 7-segment anode control (4-bit)
o_segments   : 7-segment segment control (8-bit)
o_buzzer     : Buzzer output
```

### Player Module Ports
```vhdl
i_clk_20mhz  : Clock input (20 MHz)
i_pb1_hit    : Hit button
i_pb2_stand  : Stand button
i_pb3_double : Double down button
i_uart_rx    : UART receive from dealer
o_uart_tx    : UART transmit to dealer
o_anodes     : 7-segment anode control (4-bit)
o_segments   : 7-segment segment control (8-bit)
o_leds       : LED indicators for chips (8-bit)
o_buzzer     : Buzzer output
```

## Communication Protocol

### UART Settings
- **Baud Rate**: 9600 bps
- **Clock Frequency**: 20 MHz
- **Data Format**: 8-bit, no parity, 1 stop bit

### Command Codes
| Command | Code (Hex) | Description |
|---------|------------|-------------|
| START_GAME | 0x01 | Initiate new game round |
| YOUR_TURN | 0x02 | Signal player's turn |
| RESULT_WIN | 0x10 | Player wins |
| RESULT_LOSE | 0x11 | Player loses |
| RESULT_PUSH | 0x12 | Tie (push) |
| RESULT_BJ_WIN | 0x13 | Blackjack win (1.5x payout) |
| BUST | 0x80 | Player busted |
| STAND | 0x90 | Player stands |
| ACK_SCORE | 0xA0 | Request score from player |
| BLACKJACK | 0xB0 | Player has blackjack |
| ACK_BET | 0xA1 | Confirm bet accepted |
| NO_MONEY | 0xA2 | Insufficient chips |

## Game Flow

### 1. Initialization
- Dealer waits for Start button press
- System detects connected players via KDET signals

### 2. Betting Phase
- Dealer sends START_GAME to all players
- Players confirm bets (automatic 1 chip deduction)
- Players with insufficient chips send NO_MONEY

### 3. Initial Deal
- Dealer draws one card for itself
- Players receive initial hands (random score 2-21)

### 4. Player Turns (Sequential)
- Dealer sends YOUR_TURN to each player
- Player options:
  - **Hit**: Draw another card
  - **Stand**: Keep current hand
  - **Double**: Double bet and draw one card (only before first hit)
- Player sends BUST if exceeding 21
- Player sends STAND and score when done

### 5. Dealer Turn
- Dealer reveals hand after all players finish
- Dealer must hit on 16 or below
- Dealer stands on 17 or above
- Buzzer beeps on each dealer hit

### 6. Results
- System calculates results for each player
- Sends appropriate result code to each player
- Updates player chip counts:
  - **Win**: Return bet + winnings (2x total)
  - **Blackjack**: Return bet + 1.5x winnings (2.5x total)
  - **Push**: Return bet only
  - **Loss**: Lose bet
  - **Double Win**: Return bet + double winnings (4x total)

### 7. Result Display
- Shows results for 5 seconds
- Returns to IDLE state for next game

## Display Information

### Dealer Display
- **IDLE**: Shows connected players (1-4 or dash)
- **Player Turn**: Shows "P#" + dealer score
- **Dealer Turn**: Shows dealer's current score
- **Bust**: Shows "bUSt"

### Player Display
- **IDLE Disconnected**: Shows "d---"
- **IDLE Connected**: Shows "C---" (or "   0" if no chips)
- **Playing**: Shows current score
- **Standing**: Shows score with decimal point
- **Blackjack**: Shows "  bJ"
- **Bust**: Shows "bUSt"
- **Results**: Shows "Win", "LoSE", "PUSH", or "  bJ"

## Building and Deployment

### Requirements
- Xilinx ISE or Vivado
- Spartan-3E FPGA board
- UART cables for inter-board communication
- 7-segment displays (Common Anode)
- Push buttons
- LEDs and buzzer

### Synthesis
1. Open project in Xilinx ISE/Vivado
2. Set top module to `Dealer_Main` or `Player_Main`
3. Configure UCF/XDC file for pin assignments
4. Synthesize and implement design
5. Generate bitstream
6. Program FPGA

### Clock Constraints
```
NET "i_clk_20mhz" TNM_NET = "i_clk_20mhz";
TIMESPEC "TS_i_clk_20mhz" = PERIOD "i_clk_20mhz" 50 ns HIGH 50%;
```

## Technical Details

### Random Number Generator
- 16-bit Linear Feedback Shift Register (LFSR)
- Tap positions: 16, 15, 13, 4
- Seed: 0xACE1
- Provides pseudo-random values for card drawing

### Card Distribution
- Ace (1): Can be 1 or 11 (automatic optimization)
- Cards 2-9: Face value
- Cards 10, J, Q, K: All worth 10 points
- Weighted distribution: 4 cards worth 10, 1 of each other value

### State Machine Architecture
Both Dealer and Player modules use FSM (Finite State Machine) architecture:
- **Dealer**: 28 states managing game flow and communication
- **Player**: 18 states managing player actions and responses

### Timing
- 7-Segment Refresh: 1 kHz (for multiplexing)
- UART Baud Rate: 9600 bps
- Dealer Card Draw Pause: 1 second
- Result Display: 5 seconds
- Player Turn Timeout: Audible beep every 1 second

## Troubleshooting

### Common Issues
1. **Players not detected**: Check KDET connections
2. **UART errors**: Verify baud rate and clock frequency
3. **Display flickering**: Check refresh rate in 7-segment driver
4. **Random seed issues**: Ensure RNG is enabled and seeded properly

### Debug Features
- 7-segment display shows current state
- LED indicators for player chips
- Buzzer provides audio feedback for state transitions

## Version History
- **BJ210**: Current version with buzzer support and formatted code
- **BJ201**: Previous version
- **BJ102**: Earlier iteration

## Authors
- ICHIZXC

## License
Educational Project - CE KMITL

## Acknowledgments
- Based on standard Blackjack rules
- Implemented for Digital Systems Laboratory course
- FPGA platform: Xilinx Spartan-3E
