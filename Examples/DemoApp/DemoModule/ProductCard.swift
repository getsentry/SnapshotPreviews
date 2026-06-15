//
//  ProductCard.swift
//  DemoModule
//
//  Created by Noah Martin on 7/3/23.
//

import SwiftUI
import SnapshotPreferences

struct ProductCardView: View {
    var imageName: String
    var productName: String
    var price: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(8)

            Text(productName)
                .font(.headline)
                .lineLimit(2)

            Text("$\(price, specifier: "%.2f")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: .secondary, radius: 3, x: 0, y: 2)
    }
}

struct ProductCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ProductCardView(imageName: "product-image", productName: "Sample Product 1", price: 29.99)
            .previewLayout(.sizeThatFits)
                .previewDevice(.init(rawValue: "iPad Pro (11-inch)"))
                .preferredColorScheme(.dark)

            ProductCardView(imageName: "product-image", productName: "Sample Product 2", price: 49.99)
            .previewLayout(.sizeThatFits)
        }
        .snapshotGroup("Card Views")
    }
}
