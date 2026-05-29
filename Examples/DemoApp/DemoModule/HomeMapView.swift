//
//  HomeMapView.swift
//  DemoModule
//
//  Created by Noah Martin on 7/3/23.
//

import SwiftUI
import MapKit
import SnapshotPreferences

struct Location: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}


struct HomeMapView: View {
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.332_331_41, longitude: -122.031_218_6),
                                                   span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
    let address: String

    var body: some View {
        VStack {
            Map(coordinateRegion: $region, annotationItems: [Location(coordinate: CLLocationCoordinate2D(latitude: 37.332_331_41, longitude: -122.031_218_6))]) { item in
              MapMarker(coordinate: item.coordinate)
            }
            .frame(height: 300)
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(address)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            //annotation.coordinate = region.center
        }
    }
}

struct HomeMapView_Previews: PreviewProvider {
    static var previews: some View {
        HomeMapView(address: "123 Main St, San Francisco, CA")
        .snapshotDiffThreshold(0.1)
    }
}
