//
//  BattleEngine.swift
//  PokemonBattleEngineTest
//
//  Created by Rhys Morgan on 07/01/2018.
//  Copyright © 2018 Rhys Morgan. All rights reserved.
//

import GameplayKit

struct BattleEngine: Viewable {
	private let maxTurnCount: Int
	var state: BattleState = .running {
		didSet {
			if state == .completed { view.disableButtons() }
		}
	}
	
	private(set) var winner: Player? {
		didSet {
			guard let winner = winner else { return }
//			print("Notifying delegate of winner")

			view.notifyOfWinner(winner)
			state = .completed
		}
	}
	
	private weak var view: BattleEngineViewer!
	
	private(set) var playerOne: Player
	private(set) var playerTwo: Player
	
	private(set) var turnHistory = [Turn]()
	private var turnCounter = 1
	
	private(set) var weather: Weather = .none {
		didSet {
			switch weather {
			case .none:
				view.queue(action: .displayText("The weather calmed down"))
			default:
				view.queue(action: .displayText("The weather became \(weather)"))
			}
			
			view.display(weather: weather)
		}
	}
	
	var weatherCounter = 0 {
		didSet {
			print("Weather counter = \(weatherCounter)")
			if weatherCounter == 0 {
				weather = .none
			}
		}
	}
	
	var terrain: Terrain = .none
	var terrainCounter = 0 {
		didSet {
			if terrainCounter == 0 {
				terrain = .none
			}
		}
	}
	
	var poisonCounter = 1
	
	var multiHitMoveRunning = false
	var resolveTurns = false {
		didSet {
			print("resolveTurns was set as \(resolveTurns)")
			if resolveTurns {
				run()
//				notifyViewer()
			}
		}
	}
	
	var turns: [Turn] = [] {
		didSet {
			guard !multiHitMoveRunning else { return }
			
			let containsForceSwitch = !turns.filter {
				if case .forceSwitch(_) = $0.action { return true }
				return false
			}.isEmpty
			
			let containsRun = !turns.filter { $0.action == .run }.isEmpty
			
			if (turns.count == maxTurnCount || containsForceSwitch || containsRun) && !resolveTurns {
				print("resolveTurns set to true")
				resolveTurns = true
			} else if turns.count == 0 {
				resolveTurns = false
			}
		}
	}
	
	mutating func run() {
		print("---")
		print("Turn \(turnCounter)")
		print("---")
		
		view.clear()
		
		while resolveTurns {
			print("Turns currently sorted as \(turns)")

			turns.sort {
				if $0.priority == $1.priority {
					return $0.playerSpeed > $1.playerSpeed
				} else {
					return $0.priority > $1.priority
				}
			}
			
			print("Turns now sorted as \(turns)")
			
			// Resolving turns
			
			while !turns.isEmpty {
				/* 	Lookahead to allow multi-hit moves to be added to the turns array without screwing up weather and terrain counters
					Without this code, when multi-hit moves are used, run() breaks out, and is called again multiple times,
					by resolveTurns's didSet which ends up decrementing the weather and terrain counters
				*/
				if
					let lookahead = turns.first,
					case let .attack(_,_,attack) = lookahead.action,
					case .multiHitMove(_,_)? = attack.bonusEffect
				{
					multiHitMoveRunning = true
				}
				
				let turn = turns.removeFirst()
				
				switch turn.action {
				case .attack(let attacker, var defender, let attack):
//					if defender ==  {
//						defender = playerOne.activePokemon
//					} else {
//						defender = playerTwo.activePokemon
//					}
					var damageRecipient: Pokemon
					switch defender {
					case .defender:
						if turn.player == playerOne {
							damageRecipient = playerTwo.activePokemon
						} else {
							damageRecipient = playerOne.activePokemon
						}
					case .attacker:
						if turn.player == playerOne {
							damageRecipient = playerOne.activePokemon
						} else {
							damageRecipient = playerTwo.activePokemon
						}
					}
					if attacker.status == .fainted {
						print("Not attacking, as Pokémon has fainted")
						break
					}
					
					if attacker.volatileStatus.contains(.flinch) {
						view.queue(action: .displayText("\(attacker) flinched!"))
						attacker.volatileStatus = attacker.volatileStatus.filter { $0 != .flinch }
						break
					}
					
					print("\(playerOne.name)'s \(playerOne.activePokemon!) - Lv. \(playerOne.activePokemon.level) has \(playerOne.activePokemon.currentHP)/\(playerOne.activePokemon.baseStats.hp) HP")
					print("\(playerTwo.name)'s \(playerTwo.activePokemon!) - Lv. \(playerTwo.activePokemon.level) has \(playerTwo.activePokemon.currentHP)/\(playerTwo.activePokemon.baseStats.hp) HP")
					
					func doDamage() {
						if attack.category == .status {
							view.queue(action: .useAttack(attacker: attacker, defender: damageRecipient, attack: attack))
						}
						guard attack.power > 0 else { return }
						if case .multiHitMove(_,_)? = attack.bonusEffect { return }
						
						if [.physical, .special].contains(attack.category) {
							let (baseDamage, effectiveness) = calculateDamage(attacker: attacker, defender: damageRecipient, attack: attack)
							print("\(attack.name) is going to do \(baseDamage) HP of damage against \(defender)")
							damageRecipient.damage(baseDamage)
							view.queue(action: .useAttack(attacker: attacker, defender: damageRecipient, attack: attack))
							if effectiveness != .normallyEffective {
								view.queue(action: .displayText(effectiveness.description))
							}
						}
						
					}
					
					// Have to use a value in .confused(), as you can't do .confused(_) on the right-hand side of an equation
					// but due to .confused's == behaviour, this will return true if it contains *any* .confused(value) where value != 0
					if attacker.volatileStatus.contains(.confused(1)) {
						print("\(attacker.nickname) is confused!")
						let diceRoll = GKRandomDistribution(forDieWithSideCount: 3).nextInt()
						if diceRoll == 1 {
							view.queue(action: .displayText("\(attacker.nickname) hurt itself in its confusion!"))
							let (baseDamage, _) = calculateDamage(attacker: attacker, defender: attacker, attack: Attack(name: "Confused", power: 40, basePP: 1, maxPP: 1, priority: 0, type: .typeless, category: .physical))
//							print("Confusion damage is going to do \(baseDamage) HP of damage")
							attacker.damage(baseDamage)
						} else {
							if attacker.volatileStatus.remove(.confused(0)) != nil {
								view.queue(action: .displayText("\(attacker.nickname) snapped out of it's confusion!"))
							}
							doDamage()
						}
					} else {
						if damageRecipient.volatileStatus.contains(.protected) && !attack.breaksProtect {
							view.queue(action: .displayText("\(damageRecipient.nickname) is protected!"))
							break
						} else {
							doDamage()
						}
					}
					
					func runBonusEffect(attack: Attack, target: Pokemon?) {
						switch attack.bonusEffect {
						case .singleTarget(let bonusEffect)?:
							guard let moveTarget = target else { return }
							bonusEffect(moveTarget)
						case .setWeather(let weather)?:
							setWeather(weather)
						case .setTerrain(let terrain)?:
							setTerrain(terrain)
						case let .multiHitMove(minHits, maxHits)?:
							let numberOfHits = Random.shared.between(minimum: minHits, maximum: maxHits)//GKRandomDistribution(lowestValue: minHits, highestValue: maxHits).nextInt()
							view.queue(action: .displayText("\(attack.name) will hit \(numberOfHits) times!"))
							let replacementAttack = Attack(name: attack.name, power: attack.power, basePP: 1, maxPP: 1, priority: 0, type: attack.type, breaksProtect: attack.breaksProtect, category: attack.category)
							for _ in 1...numberOfHits {
								turns.insert(Turn(player: turn.player, action: .attack(attacker: attacker, defender: defender, attack: replacementAttack)), at: turns.startIndex)
							}
						default:
							break
						}
					}
					
					switch attack.effectTarget {
					case .attacker?:
						runBonusEffect(attack: attack, target: attacker)
						print("\(attacker)'s stats are now: \(attacker.baseStats)")
					case .defender?:
						runBonusEffect(attack: attack, target: damageRecipient)
					default:
						runBonusEffect(attack: attack, target: nil)
					}
				case .switchTo(let pokemon, _), .forceSwitch(let pokemon):
					switchPokemon(player: turn.player, pokemon: pokemon)
				case .run:
					if turn.player == playerOne {
						winner = playerTwo
					} else {
						winner = playerOne
					}
					print("\(turn.player.name) has run")
					return
				case .recharge:
					let pokemon = turn.player.activePokemon!
					if pokemon.volatileStatus.contains(.mustRecharge) {
						view.queue(action: .displayText("\(pokemon) must recharge!"))
						pokemon.volatileStatus = pokemon.volatileStatus.filter { $0 != .mustRecharge }
						break
					}
				}
				
				multiHitMoveRunning = false
			}
			
			// After turns run
			for player in [playerOne, playerTwo] {
				if player.activePokemon.status == .poisoned {
					let poisonDamage = Int(ceil(Double(player.activePokemon.baseStats.hp) / 16.0))
					player.activePokemon.damage(poisonDamage)
					view.queue(action: .statusDamage(.poisoned, player.activePokemon, poisonDamage))
				}
				
				if player.activePokemon.status == .badlyPoisoned {
					let poisonDamage = Int(ceil((Double(poisonCounter) / 16.0) * Double(player.activePokemon.baseStats.hp)))
					player.activePokemon.damage(poisonDamage)
					view.queue(action: .statusDamage(.badlyPoisoned, player.activePokemon, poisonDamage))
				}
				
				player.activePokemon.volatileStatus.remove(.protected)
				player.activePokemon.volatileStatus.remove(.flinch)
				
				player.activePokemon.volatileStatus = Set(player.activePokemon.volatileStatus.map { $0.turn() })
				
				if player.activePokemon.status == .fainted {
					view.queue(action: .displayText("\(player.activePokemon!) fainted!"))
					if player == playerOne {
						view.notifyFainted(player: player, pokemon: player.activePokemon)
					}
				}
			}
			
			print("\(playerOne.name)'s \(playerOne.activePokemon!) has \(playerOne.activePokemon.currentHP)/\(playerOne.activePokemon.baseStats.hp) HP")
			print("\(playerTwo.name)'s \(playerTwo.activePokemon!) has \(playerTwo.activePokemon.currentHP)/\(playerTwo.activePokemon.baseStats.hp) HP")
			
			weatherCounter -= 1
			terrainCounter -= 1
			
			if playerOne.allFainted { winner = playerTwo }
			if playerTwo.allFainted { winner = playerOne }
			
			multiHitMoveRunning = false
			turnCounter += 1
		}
	}
	
	enum BattleType {
		case single, double
	}
	
	init(playerOne: Player, playerTwo: Player, battleType: BattleType) {
		self.playerOne = playerOne
		self.playerTwo = playerTwo
		switch battleType {
		case .single:
			self.maxTurnCount = 2
		case .double:
			self.maxTurnCount = 4
		}
	}
	
	func calculateDamage(attacker: Pokemon, defender: Pokemon, attack: Attack) -> (Int, Type.Effectiveness) {
		let attackerStat: Int
		let defenderStat: Int
		
		if attack.category == .physical {
			if attack.name == "Foul Play" {
				attackerStat = defender.baseStats.atk
			} else {
				attackerStat = attacker.baseStats.atk
			}
			defenderStat = defender.baseStats.def
		} else {
			attackerStat = attacker.baseStats.spAtk

			if attack.name == "Psyshock" {
				defenderStat = defender.baseStats.def
			} else {
				defenderStat = defender.baseStats.spDef
			}
		}
		
		let innerBrackets = (2 * attacker.level / 5) + 2
//		print("Inner brackets = \(innerBrackets)")
		
		let statCalc = attackerStat / defenderStat
		
		let unmodified = ((innerBrackets * attack.power * statCalc) / 50) + 2
		
//		print("Unmodified damage = \(unmodified)")
		
//		let rng = Double(GKRandomDistribution(lowestValue: 85, highestValue: 100).nextInt()) / 100
//		print("RNG = \(rng)")
		
		if attacker.ability.name == "Protean" {
			attacker.species.typeOne = attack.type
			attacker.species.typeTwo = nil
			view.queue(action: .abilityActivation(attacker.ability, attacker))
		}
		
		let stab: Double
		if attacker.species.typeOne == attack.type || attacker.species.typeTwo == attack.type {
			if attacker.ability.name == "Adaptability" {
				stab = 2
			} else {
				stab = 1.5
			}
		} else {
			stab = 1
		}
		stab >= 1.5 ? print("STAB activated") : print("No STAB")
		
		let typeOneEff = attack.type.typeEffectiveness(recipient: defender.species.typeOne).rawValue
		let typeTwoEff: Double
		if let typeTwo = defender.species.typeTwo {
			typeTwoEff = attack.type.typeEffectiveness(recipient: typeTwo).rawValue
		} else {
			typeTwoEff = 1
		}
		
		let effectiveness: Type.Effectiveness
		
		switch typeOneEff * typeTwoEff {
		case 0.25, 0.5:
			effectiveness = .notVeryEffective
		case 2, 4:
			effectiveness = .superEffective
		case 0:
			effectiveness = .notEffective
		default:
			effectiveness = .normallyEffective
		}
		
		let modifier = 0.85 * stab * typeOneEff * typeTwoEff
//		print("Modifier = \(modifier)")
		
		let damage = Int(floor(Double(unmodified) * modifier))
		
		return (damage, effectiveness)
	}
	
	mutating func addTurn(_ turn: Turn) {
		if !turns.isEmpty {
			switch turn.action {
			case .attack(let attacker, _, _), .switchTo(_, from: let attacker):
				removeTurns(for: attacker, belongingTo: turn.player)
				turns.append(turn)
			default:
				turns.append(turn)
			}
		} else {
			turns.append(turn)
		}
	}
	
	mutating func switchPokemon(player: Player, pokemon: Pokemon) {
		let switchingPokemon = player.activePokemon!
		player.activePokemon = pokemon
		
		switchingPokemon.volatileStatus.removeAll()
		
		view.queue(action: .switchTo(pokemon))
		view.update(with: self)
		
//		for (index, turn) in zip(turns.indices, turns) {
//			switch turn.action {
//			case let .attack(attacker, defender, attack):
////				if defender == .defender {
//					let newTurn = Turn(player: turn.player, action: .attack(attacker: attacker, defender: defender, attack: attack))
//					turns.remove(at: index)
//					turns.insert(newTurn, at: index)
////				}
//			default:
//				break
//			}
//		}
	}
	
	mutating func removeTurns(for pokemon: Pokemon, belongingTo player: Player) {
		turns = turns.filter { turn in
			switch turn.action {
			case .attack(let attacker,_,_), .switchTo(_, let attacker):
				return attacker == pokemon && turn.player == player ? false : true
			default:
				return true
			}
		}
	}
	
	
	mutating func setViewer(_ viewer: BattleEngineViewer) {
		view = viewer
	}
	
	func notifyViewer() {
		view.update(with: self)
	}
	
	private mutating func setWeather(_ weather: Weather) {
		self.weather = weather
		
		weatherCounter = 5
	}
	
	private mutating func setTerrain(_ terrain: Terrain) {
		self.terrain = terrain
		
		terrainCounter = 5
	}
	
	enum BattleState {
		case running, completed
	}
}
