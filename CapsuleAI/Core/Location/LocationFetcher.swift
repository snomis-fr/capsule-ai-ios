//
//  LocationFetcher.swift
//  CapsuleAI
//

import Foundation
import CoreLocation

actor LocationFetcher {
    private let manager = CLLocationManager()
    private var delegate: Delegate?

    func fetch() async -> (city: String?, country: String?, countryCode: String?) {
        await withCheckedContinuation { continuation in
            let d = Delegate(continuation: continuation)
            delegate = d
            manager.delegate = d
            manager.requestWhenInUseAuthorization()
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.requestLocation()
        }
    }
}

private class Delegate: NSObject, CLLocationManagerDelegate {
    typealias LocationResult = (city: String?, country: String?, countryCode: String?)
    var continuation: CheckedContinuation<LocationResult, Never>?
    let geocoder = CLGeocoder()

    init(continuation: CheckedContinuation<LocationResult, Never>) {
        self.continuation = continuation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            let pm = placemarks?.first
            self?.continuation?.resume(returning: (pm?.locality, pm?.country, pm?.isoCountryCode))
            self?.continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: (nil, nil, nil))
        continuation = nil
    }
}
