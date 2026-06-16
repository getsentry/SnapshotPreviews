//
//  FeatureCardView.swift
//  DemoModule
//
//  Created by Noah Martin on 7/3/23.
//

import SwiftUI
import SnapshotPreferences

struct FeatureCardView: View {
    var imageName: String
    var title: String
    var description: String

    var body: some View {
        VStack(spacing: 8) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .cornerRadius(12)

            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray, radius: 3, x: 0, y: 2)
    }
}

struct FeatureCardView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureCardView(imageName: "product-image",
                        title: "Feature Title",
                        description: "This is a description of the feature and its benefits.")
            .previewLayout(.sizeThatFits)
            .padding()
            .snapshotGroup("Card Views")
    }
}
