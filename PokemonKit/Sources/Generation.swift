//
//  Generation.swift
//  PokemonKit
//
//  Created by Rhys Morgan on 09/05/2018.
//  Copyright © 2018 Rhys Morgan. All rights reserved.
//

public enum Generation: String, Codable {
	case kanto, johto, hoenn, sinnoh, unova, kalos, alola, unknown
	
	init(from pokedexNumber: Int) {
		switch pokedexNumber {
		case 1...151: self = .kanto
		case 152...251: self = .johto
		case 252...386: self = .hoenn
		case 387...493: self = .sinnoh
		case 494...649: self = .unova
		case 650...721: self = .kalos
		case 722...807: self = .alola
		default: self = .unknown
		}
	}
}
