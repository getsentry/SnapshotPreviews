//
//  InfoCardView.swift
//  DemoModule
//
//  Created by Noah Martin on 7/3/23.
//

import SwiftUI
import SnapshotPreferences

struct InfoCardView: View {
    var title: String
    var description: String
    var icon: String
    var backgroundColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.white)
                .padding()
                .background(backgroundColor)
                .clipShape(Circle())

            Text(title)
                .font(.title)
                .bold()

            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray, radius: 3, x: 0, y: 2)
    }
}

struct InfoCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InfoCardView(title: "Discover", description: "Explore a world of possibilities", icon: "globe", backgroundColor: Color.blue)
                .previewLayout(.sizeThatFits)
                .padding()

            InfoCardView(title: "Connect", description: "Stay connected with loved ones", icon: "network", backgroundColor: Color.orange)
                .previewLayout(.sizeThatFits)
                .padding()
        }
        .snapshotGroup("Card Views")
    }
}
