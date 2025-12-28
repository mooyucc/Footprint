//
//  MapCoordinatePickerView.swift
//  Footprint
//
//  Created by AI Assistant on 2025/11/03.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapCoordinatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition
    @State private var pickedCoordinate: CLLocationCoordinate2D?
    @State private var isGeocoding = false
    @State private var geocodeError: String?
    
    // 选点完成后的回调（返回 MKMapItem，便于上层直接使用 placemark 信息）
    let onPicked: (MKMapItem) -> Void
    
    init(initialCoordinate: CLLocationCoordinate2D?, onPicked: @escaping (MKMapItem) -> Void) {
        self.onPicked = onPicked
        let initialCenter = initialCoordinate ?? CLLocationCoordinate2D(latitude: 34.0, longitude: 108.0)
        _cameraPosition = State(initialValue: .camera(MapCamera(centerCoordinate: initialCenter, distance: 30000)))
        _pickedCoordinate = State(initialValue: initialCoordinate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let coord = pickedCoordinate {
                        Annotation("", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    .shadow(radius: 3)
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .gesture(longPressGesture(proxy: proxy))
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    Text("long_press_on_map_to_select".localized)
                        .font(.subheadline)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.top, 10)
                }
            }
            
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("cancel".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    confirmPick()
                } label: {
                    if isGeocoding { ProgressView() } else { Text("use_this_location".localized) }
                }
                .disabled(pickedCoordinate == nil || isGeocoding)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            if let geocodeError {
                Text(geocodeError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("select_location".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func longPressGesture(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                switch value {
                case .second(true, let drag):
                    if let location = drag?.location, let coord = proxy.convert(location, from: .local) {
                        pickedCoordinate = coord
                    }
                default:
                    break
                }
            }
    }
    
    private func confirmPick() {
        guard let coord = pickedCoordinate else { return }
        isGeocoding = true
        geocodeError = nil
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                self.isGeocoding = false
                if let error = error {
                    self.geocodeError = "reverse_geocoding_failed".localized(with: error.localizedDescription)
                    // 即便失败，也返回一个最基本的 MKMapItem
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
                    self.onPicked(item)
                    self.dismiss()
                    return
                }
                if let placemark = placemarks?.first {
                    let mkPlacemark = MKPlacemark(placemark: placemark)
                    let item = MKMapItem(placemark: mkPlacemark)
                    if item.name == nil {
                        item.name = placemark.locality ?? placemark.administrativeArea ?? ""
                    }
                    self.onPicked(item)
                    self.dismiss()
                } else {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
                    self.onPicked(item)
                    self.dismiss()
                }
            }
        }
    }
}


