import HealthKit

/// A quantity type together with the fixed unit it is exported in.
struct QuantityKind: Sendable {
    let type: HKQuantityType
    let unit: HKUnit
    var identifier: String { type.identifier }
}

/// A category type together with the readable names of its values.
struct CategoryKind: Sendable {
    let type: HKCategoryType
    let valueNames: [Int: String]
    var identifier: String { type.identifier }
}

/// Everything Health50 reads. Built from the generated list of the SDK's data types. No clinical records.
enum HealthCatalog {
    static let quantities: [QuantityKind] = GeneratedHealthCatalog.quantityIdentifiers.compactMap { entry in
        guard let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: entry.identifier)),
              let unit = unit(hint: entry.unit, identifier: entry.identifier, type: type) else { return nil }
        return QuantityKind(type: type, unit: unit)
    }

    static let categories: [CategoryKind] = GeneratedHealthCatalog.categoryIdentifiers.compactMap { entry in
        guard let type = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: entry.identifier)) else { return nil }
        return CategoryKind(type: type, valueNames: GeneratedHealthCatalog.categoryValueNames[entry.valueEnum] ?? [:])
    }

    static let quantityByIdentifier: [String: QuantityKind] = Dictionary(uniqueKeysWithValues: quantities.map { ($0.identifier, $0) })

    static let correlationTypes: [HKCorrelationType] = [
        HKCorrelationType(.bloodPressure),
        HKCorrelationType(.food),
    ]

    static let scoredAssessmentTypes: [HKScoredAssessmentType] = [
        HKScoredAssessmentType(.GAD7),
        HKScoredAssessmentType(.PHQ9),
    ]

    static let characteristicTypes: [HKCharacteristicType] = [
        HKCharacteristicType(.dateOfBirth),
        HKCharacteristicType(.biologicalSex),
        HKCharacteristicType(.bloodType),
        HKCharacteristicType(.fitzpatrickSkinType),
        HKCharacteristicType(.wheelchairUse),
    ]

    /// Sample types that are tracked for changes. Correlations are left out: their members are tracked as quantities.
    static let sampleTypes: [HKSampleType] = {
        var types: [HKSampleType] = quantities.map(\.type) + categories.map(\.type)
        types.append(HKObjectType.workoutType())
        types.append(HKObjectType.electrocardiogramType())
        types.append(HKObjectType.audiogramSampleType())
        types.append(HKSeriesType.heartbeat())
        types.append(HKObjectType.stateOfMindType())
        types.append(contentsOf: scoredAssessmentTypes)
        return types
    }()

    /// What the app asks to read. Correlation types cannot be requested; their member quantities are.
    /// Types that need a separate permission per record (for example prescriptions) are left out.
    static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>(sampleTypes)
        types.insert(HKSeriesType.workoutRoute())
        types.insert(HKObjectType.activitySummaryType())
        types.formUnion(characteristicTypes)
        return types.filter { !$0.requiresPerObjectAuthorization() }
    }()

    // MARK: Units

    /// The fixed export unit of a quantity type. Starts from the unit Apple documents for the type,
    /// with two changes that make the numbers easier to read: beats and breaths per minute instead of
    /// per second, and kilometres for distances travelled.
    static func unit(hint: String, identifier: String, type: HKQuantityType) -> HKUnit? {
        var name = hint
        if name == "count/s" { name = "count/min" }
        if name == "m", identifier.hasPrefix("HKQuantityTypeIdentifierDistance"), !identifier.hasSuffix("Swimming") {
            name = "km"
        }
        if let unit = namedUnit(name), type.is(compatibleWith: unit) { return unit }
        return fallbackUnits.first { type.is(compatibleWith: $0) }
    }

    private static func namedUnit(_ name: String) -> HKUnit? {
        switch name {
        case "count": .count()
        case "count/min": .count().unitDivided(by: .minute())
        case "%": .percent()
        case "g": .gram()
        case "kg": .gramUnit(with: .kilo)
        case "m": .meter()
        case "km": .meterUnit(with: .kilo)
        case "cm": .meterUnit(with: .centi)
        case "m/s": .meter().unitDivided(by: .second())
        case "min": .minute()
        case "ms": .secondUnit(with: .milli)
        case "degC": .degreeCelsius()
        case "kcal": .kilocalorie()
        case "dBASPL": .decibelAWeightedSoundPressureLevel()
        case "W": .watt()
        case "mmHg": .millimeterOfMercury()
        case "L": .liter()
        case "mL": .literUnit(with: .milli)
        case "L/min": .liter().unitDivided(by: .minute())
        case "mg/dL": .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        case "ml/(kg*min)": .literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        case "kcal/(kg*hr)": .kilocalorie().unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .hour()))
        case "S": .siemen()
        case "IU": .internationalUnit()
        case "appleEffortScore": .appleEffortScore()
        default: nil
        }
    }

    private static let fallbackUnits: [HKUnit] = [
        .count(), .gram(), .meter(), .second(), .kilocalorie(), .degreeCelsius(), .liter(), .watt(),
        .millimeterOfMercury(), .count().unitDivided(by: .minute()), .meter().unitDivided(by: .second()),
    ]

    // MARK: Enum names

    static func name(_ enumName: String, _ value: Int) -> String? {
        GeneratedHealthCatalog.enumNames[enumName]?[value]
    }

    static func activityName(_ type: HKWorkoutActivityType) -> String {
        GeneratedHealthCatalog.workoutActivityNames[Int(type.rawValue)] ?? "other"
    }
}
