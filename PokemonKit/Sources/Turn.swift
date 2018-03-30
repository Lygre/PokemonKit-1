//
//  Turn.swift
//  PokemonBattleEngineTest
//
//  Created by Rhys Morgan on 10/01/2018.
//  Copyright © 2018 Rhys Morgan. All rights reserved.
//

import GameplayKit

public class Turn: NSObject, Codable, GKGameModelUpdate {
	public let player: Player
	let action: Action
	
	public var value: Int = 0
	
	var playerSpeed: Int {
		switch action {
		case .attack(_):
			if player.activePokemon.status == .paralysed {
				return player.activePokemon.baseStats.spd / 2
			} else {
				return player.activePokemon.baseStats.spd
			}
		default:
			return 0
		}
	}
	
	var priority: Int {
		switch action {
		case let .attack(attack):
			return attack.priority
		case .switchTo(_):
			return 6
		case .forceSwitch(_):
			return 7
		case .run:
			return 7
		case .recharge:
			return 0
		}
	}
	
	public init(player: Player, action: Action) {
		self.player = player
		self.action = action
	}
}

extension Turn {
	public static func ==(lhs: Turn, rhs: Turn) -> Bool {
		return lhs.playerSpeed == rhs.playerSpeed &&
			lhs.priority == rhs.priority &&
			lhs.action == rhs.action
	}
}

extension Turn {
	public override var description: String {
		switch action {
		case let .attack(attack):
			return "\(player.name)'s \(player.activePokemon.nickname) is going to use attack \(attack.name)"
		case let .switchTo(pokemon):
			return "\(player.name) is going to switch to \(pokemon.nickname)"
		case let .forceSwitch(pokemon):
			return "\(player.name) had to switch in \(pokemon.nickname)"
		case .run:
			return "\(player.name) is going to run"
		case .recharge:
			return "\(player.activePokemon.nickname) must recharge!"
		}
	}
}
