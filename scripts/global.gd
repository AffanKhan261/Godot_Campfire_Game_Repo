extends Node

#miner_player stat variables, start
var SPEED := 300.0
var DASH_SPEED := 520.0
var DASH_ACCEL := 2200.0
var WALK_ACCEL := 1800.0
var FRICTION := 2200.0

var JUMP_VELOCITY := -400.0
var DOUBLE_JUMP_VELOCITY := -380.0
var MAX_JUMPS := 2

# Wall jump
var WALL_JUMP_PUSH := 420.0     # horizontal push away from wall
var WALL_JUMP_VELOCITY := -420.0
var WALL_STICK_TIME := 0.12     # grace time after touching a wall
var WALL_STICK_TIMER := 0.0
#miner_player stat variables, end
