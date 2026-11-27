local _, ns = ...

local R = {}
ns.RotationData = R

R.SOURCE, R.LINK, R.FIGHT = "WoWSims Classic", "https://github.com/wowsims/classic", 180
R.CLASS = {
	WARRIOR = {
		trees = { [1] = "arms", [2] = "fury", [3] = "protection" },
		tank = "protection",
		specs = {
			arms = { label = "Arms warrior", from = "warrior.arms", dps = 1036.4,
				abilities = {
					attack = { m = 14.725, d = 0.2809 },
					bloodrage = { m = 1.288, d = 0 },
					execute = { m = 5.044, d = 0.1705 },
					hamstring = { m = 1.804, d = 0.0025 },
					["heroic strike"] = { m = 9.36, d = 0.2412 },
					["mortal strike"] = { m = 7.802, d = 0.1837 },
					["sunder armor"] = { m = 0.333, d = 0 },
					whirlwind = { m = 3.935, d = 0.0762 },
				},
				swings = { mh = 9.233, extra = 5.492, timer = 18.593, next = { ["heroic strike"] = 0.5034 } } },
			fury = { label = "Fury warrior", from = "warrior.fury", dps = 1371.9,
				abilities = {
					attack = { m = 65.475, d = 0.2846 },
					bloodrage = { m = 1.216, d = 0 },
					bloodthirst = { m = 8, d = 0.1463 },
					execute = { m = 7.349, d = 0.1778 },
					hamstring = { m = 4.644, d = 0.0045 },
					["heroic strike"] = { m = 24.794, d = 0.339 },
					["sunder armor"] = { m = 0.333, d = 0 },
					whirlwind = { m = 4.005, d = 0.0362 },
				},
				swings = { mh = 5.852, oh = 51.685, extra = 7.938, timer = 30.646, next = { ["heroic strike"] = 0.809 } } },
			protection = { label = "Protection warrior", from = "warrior.protection", dps = 538.9, tps = 1037.5,
				abilities = {
					attack = { m = 4.642, d = 0.0788, t = 0.0612 },
					bloodrage = { m = 1.002, d = 0, t = 0 },
					["heroic strike"] = { m = 24.806, d = 0.5868, t = 0.5294 },
					revenge = { m = 7.443, d = 0.0239, t = 0.0761 },
					["shield slam"] = { m = 10.032, d = 0.2669, t = 0.2949 },
					["sunder armor"] = { m = 0.288, d = 0, t = 0.0013 },
				},
				swings = { mh = 0.535, extra = 4.107, timer = 25.341, next = { ["heroic strike"] = 0.9789 } } },
		},
	},
	PALADIN = {
		trees = { [2] = "protection", [3] = "retribution" },
		tank = "protection",
		specs = {
			protection = { label = "Protection paladin", from = "paladin.protection", dps = 311.4, tps = 467,
				abilities = {
					attack = { m = 22.808, d = 0.6824, t = 0.455 },
					["holy shield"] = { m = 7.894, d = 0.0748, t = 0.1437, p = true },
					["judgement of righteousness"] = { m = 7.379, d = 0.1168, t = 0.1869 },
					["seal of righteousness"] = { m = 12.782, d = 0.0903, t = 0.1445, p = true },
				},
				swings = { mh = 20.995, extra = 1.813 } },
			retribution = { label = "Retribution paladin", from = "paladin.retribution", dps = 559.8,
				abilities = {
					attack = { m = 18.728, d = 0.7327 },
					["judgement of command"] = { m = 1.023, d = 0.0096 },
					["judgement of righteousness"] = { m = 6.009, d = 0.0818 },
					["seal of command"] = { m = 2.238, d = 0.0892, p = true },
					["seal of righteousness"] = { m = 7.935, d = 0.0759, p = true },
				},
				swings = { mh = 18.329, extra = 0.399 } },
		},
	},
	HUNTER = {
		trees = { [1] = "marksmanship", [2] = "marksmanship", [3] = "marksmanship" },
		stand = { [1] = true, [3] = true },
		specs = {
			marksmanship = { label = "Marksmanship hunter", from = "hunter.marksmanship", dps = 814.4,
				abilities = {
					["aimed shot"] = { m = 6.54, d = 0.2864 },
					["auto shot"] = { m = 21.576, d = 0.4837 },
					["multi-shot"] = { m = 5.379, d = 0.1614 },
					["serpent sting"] = { m = 5.157, d = 0.0685 },
				},
				swings = {} },
		},
	},
	ROGUE = {
		trees = { [2] = "combat" },
		specs = {
			combat = { label = "Combat rogue", from = "rogue.combat", dps = 942.5,
				abilities = {
					attack = { m = 88.127, d = 0.6021 },
					["deadly poison"] = { m = 26.789, d = 0.0359, p = true },
					eviscerate = { m = 2.34, d = 0.0677 },
					["instant poison"] = { m = 8.159, d = 0.0192, p = true },
					["sinister strike"] = { m = 19.26, d = 0.2576 },
				},
				swings = { mh = 30.962, oh = 51.246, extra = 5.919 } },
		},
	},
	PRIEST = {
		trees = { [3] = "shadow" },
		specs = {
			shadow = { label = "Shadow priest", from = "priest.shadow", dps = 579.4,
				abilities = {
					["mind blast"] = { m = 6.404, d = 0.2636 },
					["mind flay"] = { m = 14.658, d = 0.512 },
					["shadow word: pain"] = { m = 2.423, d = 0.2244 },
				},
				swings = {} },
		},
	},
	SHAMAN = {
		trees = { [1] = "elemental", [2] = "enhancement" },
		specs = {
			elemental = { label = "Elemental shaman", from = "shaman.elemental", dps = 514.4,
				abilities = {
					["chain lightning"] = { m = 4.653, d = 0.2101 },
					["lightning bolt"] = { m = 20.044, d = 0.6953 },
					["searing totem"] = { m = 1.048, d = 0.0947 },
				},
				swings = {} },
			enhancement = { label = "Enhancement shaman", from = "shaman.enhancement", dps = 717.5,
				abilities = {
					attack = { m = 24.039, d = 0.557 },
					["earth shock"] = { m = 1.859, d = 0.0298 },
					["searing totem"] = { m = 1, d = 0.0334 },
					stormstrike = { m = 2.175, d = 0.0568 },
					["windfury weapon"] = { m = 8.891, d = 0.2972, p = true },
				},
				swings = { mh = 23.394, extra = 0.645 } },
		},
	},
	MAGE = {
		trees = { [2] = "fire", [3] = "frost" },
		specs = {
			fire = { label = "Fire mage", from = "mage.fire", dps = 513.5,
				abilities = {
					fireball = { m = 11.657, d = 0.6259 },
					frostbolt = { m = 2.709, d = 0.1397 },
					scorch = { m = 0.667, d = 0.0128 },
				},
				swings = {} },
			frost = { label = "Frost mage", from = "mage.frost", dps = 634.1,
				abilities = {
					frostbolt = { m = 23.944, d = 1 },
				},
				swings = {} },
		},
	},
	WARLOCK = {
		trees = { [2] = "destruction", [3] = "destruction" },
		specs = {
			destruction = { label = "Destruction warlock", from = "warlock.destruction", dps = 675,
				abilities = {
					["bane of agony"] = { m = 2.802, d = 0.1308 },
					corruption = { m = 3.499, d = 0.1448 },
					immolate = { m = 3.581, d = 0.1059 },
					["life tap"] = { m = 3.794, d = 0 },
					["searing pain"] = { m = 0.398, d = 0.0048 },
					["shadow bolt"] = { m = 15.433, d = 0.6043 },
					shadowburn = { m = 0.303, d = 0.0093 },
				},
				swings = {} },
		},
	},
	DRUID = {
		trees = { [1] = "balance", [2] = "cat" },
		tank = "bear",
		forms = { [1] = "cat", [5] = "bear", [8] = "bear" },
		specs = {
			balance = { label = "Balance druid", from = "druid.balance", dps = 549,
				abilities = {
					moonfire = { m = 4.182, d = 0.1785 },
					starfire = { m = 14.699, d = 0.8168 },
					wrath = { m = 0.226, d = 0.0047 },
				},
				swings = {} },
			bear = { label = "Feral druid in Bear Form", from = "druid.feral_bear", dps = 602.4, tps = 2130.9,
				abilities = {
					attack = { m = 0.983, d = 0.0113, t = 0.0046 },
					maul = { m = 26.684, d = 0.5873, t = 0.4213 },
					swipe = { m = 40.088, d = 0.3961, t = 0.5682 },
				},
				swings = { mh = 0.983, timer = 27.667, next = { maul = 0.9645 } } },
			cat = { label = "Feral druid in Cat Form", from = "druid.feral_cat", dps = 1173.6,
				abilities = {
					attack = { m = 87.429, d = 0.4157 },
					claw = { m = 0.384, d = 0.0036 },
					["ferocious bite"] = { m = 5.731, d = 0.1827 },
					shred = { m = 24.718, d = 0.3877 },
				},
				swings = { mh = 87.429 } },
		},
	},
}
