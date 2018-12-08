A low-level pipe-line communication system for complete-takeover dota 2 bots while maintaining team-based data concurrency, and avoiding bot-to-bot data redundancy--All implemented with only Lua and the Dota 2 bot API. 

Team data is not stored concurrently in the LUA state, because I am an idiot.

Regularly uses two 4.65 kb/s (i & o speed) data buffers for both teams, separately, with emergency data transfer reaching 11.55 kb/s for a team if i/o stacks become too long.

No additional setup is required. Just place in your vscripts/bots/ folder and go.