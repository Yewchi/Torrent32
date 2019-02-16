A low-level pipe-line communication system for complete-takeover dota 2 bots while maintaining team-based data concurrency, and avoiding bot-to-bot data redundancy--via only pinging the map.

Team data is not stored concurrently in the LUA state, because I am an idiot. Instead it is stored within the Team Captain's LUA state, and instructions are given by interpreting the bit data which can be set in the 22-precise-bits of each 32-bit ping for all bots on the team--for absolutely no reason. Because LUA has it's own method of indicating negative numbers, and has no overflow, 22-bit signed integers and their overflow are simulated via the bitwise_interface.lua functions--such that pushing data to the bits and then performing each ping (once the data is decided) fully uses the precise bit-space, even if the numbers resulting would have been negative.

Regularly uses two 4.65 kb/s (i & o speed) data buffers for both teams, separately, with emergency data transfer reaching 11.55 kb/s for a team if i/o stacks become too long.

No additional setup is required. Just place in your vscripts/bots/ folder and go.

Requires an instruction table, and needs a detailed instruction interpretation module.

Basic instruction interpretation is currently hard-coded only for basic movement.
