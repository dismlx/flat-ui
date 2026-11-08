local _, ns = ...

-- The class abilities a player casts on an enemy, and those of the hunter's and the warlock's pets, for the guess of the combat text at which
-- action of yours made a hit (CombatText.lua, MINE). The key is the spell ID of the first rank. CombatText.lua asks the client for the name of
-- each at load, so every rank and every language matches by name.
-- school: the school mask (1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane). kind: "hit" makes one hit when the cast
-- succeeds or lands, "dot" no hit when cast and ticks after, "both" a hit and then ticks, "channel" hits while it is channelled, "area" several
-- hits at once around you or a spot, and "none" no damage at all, so its cast opens no slot (its school is not used). travel: the missile
-- flies (its SpellMisc Speed is above 0), so the hit comes later. Auto Shot, the shots of a bow, gun, crossbow or thrown weapon and the Shoot of
-- a wand are left out: the shot slot takes them (MINE.shots). Maul, Heroic Strike, Cleave and Raptor Strike are here too, but their cast opens
-- the next-swing slot (MINE.nextSwing) before this table is read.
-- Checked against the game's tables. The name of each ID: the classic client's Spell table (WowClassicGrindBot, Json/dbc/spells.json: Id, Name,
-- Level) and SpellName of the Retail dumps (ThingEngineering/wow-dumps, te_spellname.csv). School and missile: SpellMisc of those dumps
-- (SchoolMask, Speed). Kind: SpellEffect of those dumps, with the spells its EffectTriggerSpell names: Effect 2, 9, 17, 31, 58, 62 or 121 is a
-- hit, an aura of EffectAura 3, 53 or 89 ticks, and EffectAura 23 is a channel or an area of triggered hits. The dumps are of Retail, which has
-- dropped or reused many classic IDs: "no row" marks an ID they hold no row for and "now X" one whose Retail row is named X. For both, the
-- school, the missile and the effects are those of the Retail rows of the classic name. "classic" marks a kind or a school taken from the
-- classic spell where Retail's rows were changed since (a burn dropped, a hit added, a school changed).
ns.CombatSpells = {
	-- Mage
	[133] = { school = 4, kind = "both", travel = true }, -- Fireball (classic: a burn after the hit; Retail's row has the hit alone)
	[116] = { school = 16, kind = "hit", travel = true }, -- Frostbolt
	[2136] = { school = 4, kind = "hit" }, -- Fire Blast (no row)
	[5143] = { school = 64, kind = "channel" }, -- Arcane Missiles
	[1449] = { school = 64, kind = "area" }, -- Arcane Explosion
	[122] = { school = 16, kind = "area" }, -- Frost Nova
	[120] = { school = 16, kind = "area" }, -- Cone of Cold
	[10] = { school = 16, kind = "channel" }, -- Blizzard (no row)
	[2120] = { school = 4, kind = "area" }, -- Flamestrike (the burn on the spot after it ticks as an aura)
	[11366] = { school = 4, kind = "both", travel = true }, -- Pyroblast (classic: a burn after the hit)
	[2948] = { school = 4, kind = "hit" }, -- Scorch
	[11113] = { school = 4, kind = "area" }, -- Blast Wave (no row)
	[118] = { school = 64, kind = "none" }, -- Polymorph (the pig and turtle ranks have the same name)
	[2139] = { school = 64, kind = "none" }, -- Counterspell
	[2855] = { school = 64, kind = "none" }, -- Detect Magic (no row, none of the same name)
	-- Warlock
	[686] = { school = 32, kind = "hit", travel = true }, -- Shadow Bolt
	[348] = { school = 4, kind = "both" }, -- Immolate
	[172] = { school = 32, kind = "dot" }, -- Corruption (classic: ticks only; Retail's row adds a hit)
	[980] = { school = 32, kind = "dot" }, -- Curse of Agony (now Agony)
	[702] = { school = 32, kind = "none" }, -- Curse of Weakness
	[704] = { school = 32, kind = "none" }, -- Curse of Recklessness (no row)
	[1714] = { school = 32, kind = "none" }, -- Curse of Tongues
	[1490] = { school = 32, kind = "none" }, -- Curse of the Elements (now Chaos Brand)
	[17862] = { school = 32, kind = "none" }, -- Curse of Shadow (no row, none of the same name)
	[603] = { school = 32, kind = "dot" }, -- Curse of Doom (now Doom; one tick after 60 seconds)
	[18223] = { school = 32, kind = "none" }, -- Curse of Exhaustion (no row)
	[689] = { school = 32, kind = "channel" }, -- Drain Life (no row)
	[1120] = { school = 32, kind = "channel" }, -- Drain Soul (no row)
	[5138] = { school = 32, kind = "none" }, -- Drain Mana (no row; classic school; channelled, it drains mana and does no damage)
	[1949] = { school = 4, kind = "channel" }, -- Hellfire
	[5740] = { school = 4, kind = "channel" }, -- Rain of Fire (classic: channelled)
	[5676] = { school = 4, kind = "hit" }, -- Searing Pain (no row)
	[6353] = { school = 4, kind = "hit", travel = true }, -- Soul Fire
	[17877] = { school = 32, kind = "hit" }, -- Shadowburn (classic school; Retail's row holds 36, fire and shadow)
	[17962] = { school = 4, kind = "hit" }, -- Conflagrate
	[6789] = { school = 32, kind = "hit", travel = true }, -- Death Coil (now Mortal Coil)
	[18265] = { school = 32, kind = "dot" }, -- Siphon Life (no row)
	[5782] = { school = 32, kind = "none" }, -- Fear
	[5484] = { school = 32, kind = "none" }, -- Howl of Terror
	[710] = { school = 32, kind = "none" }, -- Banish
	[1098] = { school = 32, kind = "none" }, -- Enslave Demon (now Subjugate Demon)
	[1122] = { school = 4, kind = "area", travel = true }, -- Inferno (now Summon Infernal, Speed 1)
	-- Warlock's demons
	[3110] = { school = 4, kind = "hit", travel = true }, -- Firebolt (Imp)
	[3716] = { school = 32, kind = "none" }, -- Torment (Voidwalker; now Consuming Shadows; classic school)
	[17735] = { school = 32, kind = "none" }, -- Suffering (Voidwalker)
	[7814] = { school = 32, kind = "hit" }, -- Lash of Pain (Succubus)
	[6358] = { school = 32, kind = "none" }, -- Seduction (Succubus; channelled)
	[6360] = { school = 32, kind = "none" }, -- Soothing Kiss (Succubus; now Whiplash, none of the same name)
	[19244] = { school = 32, kind = "none" }, -- Spell Lock (Felhunter; no row)
	[19505] = { school = 32, kind = "none" }, -- Devour Magic (Felhunter)
	-- Priest
	[585] = { school = 2, kind = "hit" }, -- Smite
	[14914] = { school = 2, kind = "both" }, -- Holy Fire
	[589] = { school = 32, kind = "dot" }, -- Shadow Word: Pain (classic: ticks only; Retail's row adds a hit)
	[8092] = { school = 32, kind = "hit" }, -- Mind Blast
	[15407] = { school = 32, kind = "channel" }, -- Mind Flay
	[15237] = { school = 2, kind = "area" }, -- Holy Nova (no row)
	[8129] = { school = 32, kind = "hit" }, -- Mana Burn (no row)
	[8122] = { school = 32, kind = "none" }, -- Psychic Scream
	[605] = { school = 32, kind = "none" }, -- Mind Control (channelled)
	[453] = { school = 32, kind = "none" }, -- Mind Soothe
	[2096] = { school = 32, kind = "none" }, -- Mind Vision (channelled)
	[15487] = { school = 32, kind = "none" }, -- Silence
	[15286] = { school = 32, kind = "none" }, -- Vampiric Embrace
	[9484] = { school = 2, kind = "none" }, -- Shackle Undead (now Shackle Horror; classic school)
	[527] = { school = 2, kind = "none" }, -- Dispel Magic (now Purify)
	[10797] = { school = 64, kind = "channel" }, -- Starshards (no row; the four rows of the name are channelled)
	[2944] = { school = 32, kind = "dot" }, -- Devouring Plague (no row; classic: ticks only)
	[9035] = { school = 32, kind = "none" }, -- Hex of Weakness (no row)
	-- Druid
	[5176] = { school = 8, kind = "hit", travel = true }, -- Wrath
	[8921] = { school = 64, kind = "both" }, -- Moonfire (classic: a hit and ticks; Retail's row is a dummy)
	[2912] = { school = 64, kind = "hit" }, -- Starfire (no row)
	[5570] = { school = 8, kind = "dot" }, -- Insect Swarm (no row)
	[16914] = { school = 8, kind = "channel" }, -- Hurricane (classic: channelled)
	[339] = { school = 8, kind = "dot" }, -- Entangling Roots
	[770] = { school = 8, kind = "none" }, -- Faerie Fire (no row)
	[16857] = { school = 8, kind = "none" }, -- Faerie Fire (Feral) (no row, none of the same name)
	[2637] = { school = 8, kind = "none" }, -- Hibernate
	[2908] = { school = 8, kind = "none" }, -- Soothe Animal (now Soothe)
	[1082] = { school = 1, kind = "hit" }, -- Claw (no row)
	[1822] = { school = 1, kind = "both" }, -- Rake
	[1079] = { school = 1, kind = "dot" }, -- Rip
	[22568] = { school = 1, kind = "hit" }, -- Ferocious Bite
	[5221] = { school = 1, kind = "hit" }, -- Shred
	[6785] = { school = 1, kind = "hit" }, -- Ravage (no row)
	[9005] = { school = 1, kind = "dot" }, -- Pounce (no row; classic: a stun, then Pounce Bleed ticks)
	[5211] = { school = 1, kind = "none" }, -- Bash (now Mighty Bash; classic: a stun only)
	[779] = { school = 1, kind = "area" }, -- Swipe (no row)
	[6807] = { school = 1, kind = "hit" }, -- Maul (a next swing)
	[99] = { school = 1, kind = "none" }, -- Demoralizing Roar (now Incapacitating Roar)
	[6795] = { school = 1, kind = "none" }, -- Growl
	[5209] = { school = 1, kind = "none" }, -- Challenging Roar (no row, none of the same name)
	[16979] = { school = 1, kind = "none" }, -- Feral Charge (now Wild Charge)
	[8998] = { school = 1, kind = "none" }, -- Cower (no row)
	-- Hunter
	[3044] = { school = 64, kind = "hit", travel = true }, -- Arcane Shot (no row)
	[1978] = { school = 8, kind = "dot", travel = true }, -- Serpent Sting (no row)
	[3034] = { school = 8, kind = "none", travel = true }, -- Viper Sting (no row; it drains mana)
	[3043] = { school = 8, kind = "none", travel = true }, -- Scorpid Sting (no row)
	[5116] = { school = 1, kind = "none", travel = true }, -- Concussive Shot
	[19434] = { school = 1, kind = "hit", travel = true }, -- Aimed Shot
	[2643] = { school = 1, kind = "area", travel = true }, -- Multi-Shot
	[1510] = { school = 64, kind = "channel" }, -- Volley (no row; classic school, arcane: most rows of the name are physical)
	[1130] = { school = 64, kind = "none" }, -- Hunter's Mark
	[20736] = { school = 64, kind = "none", travel = true }, -- Distracting Shot
	[2974] = { school = 1, kind = "hit" }, -- Wing Clip (no row)
	[2973] = { school = 1, kind = "hit" }, -- Raptor Strike (no row; a next swing)
	[1495] = { school = 1, kind = "hit" }, -- Mongoose Bite (no row)
	[19306] = { school = 1, kind = "hit" }, -- Counterattack (no row)
	[19386] = { school = 8, kind = "none", travel = true }, -- Wyvern Sting (the sleep; its ticks come after it, from another spell)
	[19503] = { school = 1, kind = "hit", travel = true }, -- Scatter Shot (no row; Retail's Scatter Shot 213691 has Speed 60)
	[19801] = { school = 8, kind = "none", travel = true }, -- Tranquilizing Shot
	[1499] = { school = 16, kind = "none" }, -- Freezing Trap (no row; a trap's cast places it and it hits later)
	[13795] = { school = 4, kind = "none" }, -- Immolation Trap (no row)
	[13813] = { school = 4, kind = "none" }, -- Explosive Trap
	[13809] = { school = 16, kind = "none" }, -- Frost Trap (now Ice Trap)
	[1543] = { school = 64, kind = "none", travel = true }, -- Flare
	[19577] = { school = 8, kind = "none" }, -- Intimidation
	[781] = { school = 1, kind = "none" }, -- Disengage (classic: lowers threat; Retail's is a leap)
	[1513] = { school = 8, kind = "none" }, -- Scare Beast
	[1515] = { school = 8, kind = "none" }, -- Tame Beast (channelled)
	-- Hunter's pets
	[17253] = { school = 1, kind = "hit" }, -- Bite
	[16827] = { school = 1, kind = "hit" }, -- Claw (the druid's has the same name and entry)
	[2649] = { school = 1, kind = "none" }, -- Growl
	[24423] = { school = 1, kind = "hit" }, -- Screech (now Bloody Screech)
	[7371] = { school = 1, kind = "none" }, -- Charge (boar; no row)
	[24844] = { school = 8, kind = "hit" }, -- Lightning Breath (no row)
	[24640] = { school = 8, kind = "dot" }, -- Scorpid Poison
	[26090] = { school = 8, kind = "area" }, -- Thunderstomp (no row)
	[1742] = { school = 1, kind = "none" }, -- Cower (no row)
	-- Rogue
	[1752] = { school = 1, kind = "hit" }, -- Sinister Strike
	[53] = { school = 1, kind = "hit" }, -- Backstab
	[2098] = { school = 1, kind = "hit" }, -- Eviscerate (now Dispatch)
	[1776] = { school = 1, kind = "hit" }, -- Gouge (classic: it hits)
	[703] = { school = 1, kind = "dot" }, -- Garrote
	[1943] = { school = 1, kind = "dot" }, -- Rupture
	[8676] = { school = 1, kind = "hit" }, -- Ambush
	[16511] = { school = 1, kind = "hit" }, -- Hemorrhage
	[14278] = { school = 1, kind = "hit" }, -- Ghostly Strike (no row; classic school: two of the three rows of the name are shadow)
	[14251] = { school = 1, kind = "hit" }, -- Riposte (no row)
	[1766] = { school = 1, kind = "hit" }, -- Kick (classic: it hits)
	[6770] = { school = 1, kind = "none" }, -- Sap
	[1833] = { school = 1, kind = "none" }, -- Cheap Shot
	[408] = { school = 1, kind = "none" }, -- Kidney Shot
	[2094] = { school = 1, kind = "none" }, -- Blind
	[8647] = { school = 1, kind = "none" }, -- Expose Armor (now Mystic Touch)
	[1725] = { school = 1, kind = "none" }, -- Distract
	[1966] = { school = 1, kind = "none" }, -- Feint
	[921] = { school = 1, kind = "none" }, -- Pick Pocket
	[14183] = { school = 1, kind = "none" }, -- Premeditation (no row)
	-- Warrior
	[78] = { school = 1, kind = "hit" }, -- Heroic Strike (no row; a next swing)
	[845] = { school = 1, kind = "area" }, -- Cleave (a next swing)
	[772] = { school = 1, kind = "dot" }, -- Rend (classic: ticks only; Retail's row is a hit)
	[6343] = { school = 1, kind = "area" }, -- Thunder Clap
	[1715] = { school = 1, kind = "hit" }, -- Hamstring
	[7384] = { school = 1, kind = "hit" }, -- Overpower
	[12294] = { school = 1, kind = "hit" }, -- Mortal Strike
	[23881] = { school = 1, kind = "hit" }, -- Bloodthirst
	[23922] = { school = 1, kind = "hit" }, -- Shield Slam
	[6572] = { school = 1, kind = "hit" }, -- Revenge (classic: one enemy; Retail's hits a cone)
	[5308] = { school = 1, kind = "hit" }, -- Execute
	[1464] = { school = 1, kind = "hit" }, -- Slam
	[1680] = { school = 1, kind = "area" }, -- Whirlwind
	[7386] = { school = 1, kind = "none" }, -- Sunder Armor (no row)
	[1160] = { school = 1, kind = "none" }, -- Demoralizing Shout
	[5246] = { school = 1, kind = "none" }, -- Intimidating Shout
	[1161] = { school = 1, kind = "none" }, -- Challenging Shout
	[355] = { school = 1, kind = "none" }, -- Taunt
	[694] = { school = 1, kind = "hit" }, -- Mocking Blow (no row)
	[676] = { school = 1, kind = "none" }, -- Disarm (no row)
	[100] = { school = 1, kind = "none" }, -- Charge
	[20252] = { school = 1, kind = "hit" }, -- Intercept (no row)
	[6552] = { school = 1, kind = "hit" }, -- Pummel (classic: it hits)
	[72] = { school = 1, kind = "hit" }, -- Shield Bash (no row)
	[12323] = { school = 1, kind = "none" }, -- Piercing Howl
	[12809] = { school = 1, kind = "none" }, -- Concussion Blow (no row; classic: a stun only)
	-- Paladin
	[20271] = { school = 2, kind = "hit" }, -- Judgement (now Judgment; as the row Judgement 343122: no missile. Only a judged Seal of Righteousness or Command hits)
	[879] = { school = 2, kind = "hit" }, -- Exorcism (no row)
	[20473] = { school = 2, kind = "hit" }, -- Holy Shock (classic: a hit on an enemy, a heal on a friend; Retail's row is a dummy)
	[24275] = { school = 2, kind = "hit", travel = true }, -- Hammer of Wrath
	[26573] = { school = 2, kind = "area" }, -- Consecration
	[2812] = { school = 2, kind = "area" }, -- Holy Wrath (now Denounce)
	[853] = { school = 2, kind = "none" }, -- Hammer of Justice (classic: a stun only; Retail's row adds a hit)
	[2878] = { school = 2, kind = "none" }, -- Turn Undead (no row; the two rows of the name are nature)
	[20066] = { school = 2, kind = "none" }, -- Repentance
	-- Shaman
	[403] = { school = 8, kind = "hit", travel = true }, -- Lightning Bolt (no row)
	[421] = { school = 8, kind = "area" }, -- Chain Lightning (no row)
	[8042] = { school = 8, kind = "hit" }, -- Earth Shock
	[8050] = { school = 4, kind = "both" }, -- Flame Shock (no row)
	[8056] = { school = 16, kind = "hit" }, -- Frost Shock (no row)
	[370] = { school = 8, kind = "none" }, -- Purge
	[17364] = { school = 1, kind = "hit" }, -- Stormstrike
	[3599] = { school = 4, kind = "none" }, -- Searing Totem (a totem's cast places it; its own hits come later)
	[8190] = { school = 4, kind = "none" }, -- Magma Totem
	[1535] = { school = 4, kind = "none" }, -- Fire Nova Totem (no row)
	[5730] = { school = 8, kind = "none" }, -- Stoneclaw Totem (no row, none of the same name)
	[2484] = { school = 8, kind = "none" }, -- Earthbind Totem
}
