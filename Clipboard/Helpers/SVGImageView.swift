//
//  SVGImageView.swift
//  Clipboard
//
//  Created by Aayush Giri on 27/10/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A view that displays chain logos from SVG files
struct ChainLogoView: View {
    let cryptoType: CryptoType
    let size: CGFloat

    var body: some View {
        // Load SVG from bundle
        if !svgFileName.isEmpty,
           let svgPath = Bundle.main.path(forResource: svgFileName, ofType: "svg"),
           let svgData = try? Data(contentsOf: URL(fileURLWithPath: svgPath)),
           let nsImage = NSImage(data: svgData) {
            // SVG loaded successfully - show on white circular background
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)

                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.7, height: size * 0.7)
            }
        } else {
            // Fallback: Use colored SF Symbol with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                cryptoType.color,
                                cryptoType.color.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)

                Image(systemName: cryptoType.iconName)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var svgFileName: String {
        switch cryptoType {
        case .bitcoin:
            return "bitcoin-btc-logo"
        case .ethereum:
            return "ethereum-eth-logo-colored"
        case .solana:
            return "solana-sol-logo"
        case .litecoin, .dogecoin, .monero, .unknown:
            return "" // No SVG available, will use fallback
        }
    }
}

// Extension to add color and icon properties to CryptoType
extension CryptoType {
    var color: Color {
        switch self {
        case .bitcoin:
            return Color(red: 0.97, green: 0.58, blue: 0.10) // #F7931A - Bitcoin Orange
        case .ethereum:
            return Color(red: 0.38, green: 0.51, blue: 0.76) // #627EEA - Ethereum Blue
        case .solana:
            return Color(red: 0.56, green: 0.24, blue: 0.85) // #8E3FD6 - Solana Purple
        case .litecoin:
            return Color(red: 0.20, green: 0.40, blue: 0.66) // #345D9D - Litecoin Blue
        case .dogecoin:
            return Color(red: 0.79, green: 0.65, blue: 0.26) // #C9A526 - Dogecoin Gold
        case .monero:
            return Color(red: 1.0, green: 0.39, blue: 0.0) // #FF6400 - Monero Orange
        case .unknown:
            return Color.gray
        }
    }

    var iconName: String {
        switch self {
        case .bitcoin:
            return "bitcoinsign.circle.fill"
        case .ethereum:
            return "e.circle.fill"
        case .solana:
            return "s.circle.fill"
        case .litecoin:
            return "l.circle.fill"
        case .dogecoin:
            return "d.circle.fill"
        case .monero:
            return "m.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

#if os(macOS)
/// Haptic feedback helper for macOS
class HapticFeedback {
    static let shared = HapticFeedback()

    func light() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    func medium() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    func success() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    func warning() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    func error() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}
#endif
