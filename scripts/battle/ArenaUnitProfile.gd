class_name ArenaUnitProfile
extends Resource
## Movement, basic attack, and initial equipment; base stats stay in HeroData.

@export var basic_attack_range := 1.01
@export var magic_basic_attack := false
@export var move_interval_seconds := 0.28
@export var abilities: Array[ArenaAbilityData] = []
