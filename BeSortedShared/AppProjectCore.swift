//
//  AppProjectCore.swift
//  BeSortedShared
//

import Foundation

enum AppCategory: String, CaseIterable, Identifiable {
    case ecommerce
    case socialMedia
    case productivity
    case business
    case fitness
    case education
    case travel
    case lifestyle
    case utility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ecommerce: "E-commerce"
        case .socialMedia: "Social Media"
        case .productivity: "Produktywność"
        case .business: "Biznesowa"
        case .fitness: "Fitness"
        case .education: "Edukacja"
        case .travel: "Podróże"
        case .lifestyle: "Lifestyle"
        case .utility: "Utility"
        }
    }
}