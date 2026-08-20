# Three Stats; swing rate is Attack interval

Units have three Stats — Strength, Dexterity, and Constitution. SPD is gone. How often a unit attacks is **Attack interval** (authored on the Weapon or enemy combat profile, optionally scaled by Seals and some Fertilizers), not a Stat. Battle physics process order is random; we do not sort by Attack interval.

**Considered options:** fold swing rate into Dexterity (rejected — DEX already feeds damage; Bow would double-dip); keep a hidden speed number (rejected — same system with the label peeled off); sort process order by fastest Attack interval (rejected — tiebreaks got too complex).
