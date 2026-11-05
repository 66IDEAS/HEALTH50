import CoreLocation
import HealthKit
import SwiftUI

/// Developer tool for the simulator: writes a small, varied set of test records into Health.
@main
struct SeederApp: App {
    var body: some Scene {
        WindowGroup { SeederView() }
    }
}

struct SeederView: View {
    @State private var message = "Requesting write access…"

    var body: some View {
        Text(message).font(.title3).multilineTextAlignment(.center).padding()
            .task { await seed() }
    }

    private func quantityType(_ id: HKQuantityTypeIdentifier) -> HKQuantityType { HKQuantityType(id) }

    private func seed() async {
        #if !targetEnvironment(simulator)
        message = "This tool only runs in the simulator."
        #else
        let store = HKHealthStore()
        let share: Set<HKSampleType> = [
            quantityType(.bodyMass), quantityType(.stepCount), quantityType(.heartRate),
            quantityType(.bloodPressureSystolic), quantityType(.bloodPressureDiastolic),
            quantityType(.activeEnergyBurned), quantityType(.distanceWalkingRunning),
            HKCategoryType(.sleepAnalysis), HKCategoryType(.mindfulSession), HKCategoryType(.headache),
            HKObjectType.workoutType(), HKSeriesType.workoutRoute(),
        ]
        do {
            try await store.requestAuthorization(toShare: share, read: [])
            let now = Date.now
            let day = 86_400.0
            var samples: [HKSample] = []

            // Weight in three different months, one entered by hand.
            for (offset, kg) in [(1.0, 81.4), (40.0, 82.0), (75.0, 82.6)] {
                let date = now.addingTimeInterval(-offset * day)
                samples.append(HKQuantitySample(type: quantityType(.bodyMass), quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                                start: date, end: date, metadata: [HKMetadataKeyWasUserEntered: true]))
            }
            // Steps: hourly for two days, plus a few older ones.
            for hour in 0..<48 {
                let start = now.addingTimeInterval(-Double(hour + 1) * 3600)
                samples.append(HKQuantitySample(type: quantityType(.stepCount), quantity: HKQuantity(unit: .count(), doubleValue: Double(200 + (hour * 37) % 600)),
                                                start: start, end: start.addingTimeInterval(3000)))
            }
            for offset in [40.0, 41.0, 75.0] {
                let start = now.addingTimeInterval(-offset * day)
                samples.append(HKQuantitySample(type: quantityType(.stepCount), quantity: HKQuantity(unit: .count(), doubleValue: 4321),
                                                start: start, end: start.addingTimeInterval(3600)))
            }
            // Heart rate every five minutes for a day.
            let bpm = HKUnit.count().unitDivided(by: .minute())
            for index in 0..<288 {
                let date = now.addingTimeInterval(-Double(index) * 300)
                samples.append(HKQuantitySample(type: quantityType(.heartRate), quantity: HKQuantity(unit: bpm, doubleValue: Double(56 + (index * 7) % 40)),
                                                start: date, end: date, metadata: [HKMetadataKeyHeartRateMotionContext: 1]))
            }
            // Last night's sleep in phases.
            let bedtime = Calendar.current.startOfDay(for: now).addingTimeInterval(-1.5 * 3600)
            let phases: [(HKCategoryValueSleepAnalysis, Double)] = [(.asleepCore, 70), (.asleepDeep, 45), (.asleepCore, 90), (.asleepREM, 30), (.awake, 5), (.asleepCore, 120)]
            var cursor = bedtime
            for (phase, minutes) in phases {
                let end = cursor.addingTimeInterval(minutes * 60)
                samples.append(HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: phase.rawValue, start: cursor, end: end))
                cursor = end
            }
            samples.append(HKCategorySample(type: HKCategoryType(.mindfulSession), value: HKCategoryValue.notApplicable.rawValue,
                                            start: now.addingTimeInterval(-3 * 3600), end: now.addingTimeInterval(-3 * 3600 + 600)))
            samples.append(HKCategorySample(type: HKCategoryType(.headache), value: HKCategoryValueSeverity.mild.rawValue,
                                            start: now.addingTimeInterval(-5 * 3600), end: now.addingTimeInterval(-4 * 3600)))
            // A blood pressure reading: two values that belong together.
            let reading = now.addingTimeInterval(-2 * 3600)
            let systolic = HKQuantitySample(type: quantityType(.bloodPressureSystolic), quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 122), start: reading, end: reading)
            let diastolic = HKQuantitySample(type: quantityType(.bloodPressureDiastolic), quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: 78), start: reading, end: reading)
            samples.append(HKCorrelation(type: HKCorrelationType(.bloodPressure), start: reading, end: reading, objects: [systolic, diastolic]))

            try await store.save(samples)

            // A 30 minute run yesterday with energy, distance and a GPS route.
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .running
            configuration.locationType = .outdoor
            let runStart = now.addingTimeInterval(-day - 3600)
            let runEnd = runStart.addingTimeInterval(1805)
            let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
            try await builder.beginCollection(at: runStart)
            try await builder.addSamples([
                HKQuantitySample(type: quantityType(.activeEnergyBurned), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 312.4), start: runStart, end: runEnd),
                HKQuantitySample(type: quantityType(.distanceWalkingRunning), quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: 5.02), start: runStart, end: runEnd),
            ])
            try await builder.addWorkoutEvents([
                HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: runStart.addingTimeInterval(700), duration: 0), metadata: nil),
                HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: runStart.addingTimeInterval(738), duration: 0), metadata: nil),
            ])
            try await builder.addMetadata([HKMetadataKeyIndoorWorkout: false])
            try await builder.endCollection(at: runEnd)
            var routeNote = ""
            if let workout = try await builder.finishWorkout() {
                let route = HKWorkoutRouteBuilder(healthStore: store, device: nil)
                let locations = (0..<60).map { index in
                    CLLocation(coordinate: CLLocationCoordinate2D(latitude: 47.3769 + Double(index) * 0.0002, longitude: 8.5417 + Double(index) * 0.0003),
                               altitude: 408 + Double(index % 5), horizontalAccuracy: 4.2, verticalAccuracy: 3,
                               course: 45, speed: 2.9, timestamp: runStart.addingTimeInterval(Double(index) * 30))
                }
                try await route.insertRouteData(locations)
                try await route.finishRoute(with: workout, metadata: nil)
                routeNote = " and one run with a route"
            }
            message = "Done. Wrote \(samples.count) records\(routeNote).\nYou can close this app."
        } catch {
            message = "Failed: \(error.localizedDescription)"
        }
        #endif
    }
}
