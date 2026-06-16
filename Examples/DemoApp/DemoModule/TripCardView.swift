//
//  TripCardView.swift
//  DemoModule
//
//  Created by Noah Martin on 7/3/23.
//

import SwiftUI
import SnapshotPreferences

struct TripCardView: View {
    var destination: String
    var checkInDate: String
    var checkOutDate: String
    var imageName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
          Rectangle()
            .frame(height: 200)
            .foregroundColor(.clear)
            .background(
              Image(imageName)
                .resizable()
                .cornerRadius(12))

            Text(destination)
                .font(.title)
                .fontWeight(.bold)

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)

                Text("\(checkInDate) - \(checkOutDate)")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray, radius: 3, x: 0, y: 2)
    }
}

struct TripCardView_Previews: PreviewProvider {
    static var previews: some View {
        TripCardView(destination: "Paris, France",
                     checkInDate: "Aug 22",
                     checkOutDate: "Aug 28",
                     imageName: "product-image")
            .previewLayout(.device)
            .padding()
            .snapshotGroup("Card Views")
    }
}
