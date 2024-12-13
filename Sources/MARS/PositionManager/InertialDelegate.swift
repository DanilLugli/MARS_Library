//
//  InertialDelegate.swift
//  MARS
//
//  Created by Danil Lugli on 23/11/24.
//

import Foundation
import CoreMotion

// MARK: - Kalman Filter
class KalmanFilter {
    var estimate: Double
    var errorCovariance: Double
    var processNoise: Double
    var measurementNoise: Double

    init(initialEstimate: Double, initialErrorCovariance: Double, processNoise: Double, measurementNoise: Double) {
        self.estimate = initialEstimate
        self.errorCovariance = initialErrorCovariance
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
    }

    func update(measurement: Double) -> Double {
        // Predizione
        errorCovariance += processNoise

        // Guadagno di Kalman
        let kalmanGain = errorCovariance / (errorCovariance + measurementNoise)

        // Aggiorna la stima
        estimate += kalmanGain * (measurement - estimate)

        // Aggiorna la covarianza dell'errore
        errorCovariance *= (1 - kalmanGain)

        return estimate
    }
}

// MARK: - IMU State
struct IMUState {
    var pitch: Double
    var roll: Double
    var heading: Double
    var position: (x: Double, y: Double)
}

// MARK: - Sensor Data
struct SensorData {
    var accelerometer: CMAcceleration
    var gyroscope: CMRotationRate
    var magnetometer: CMMagneticField
}

// MARK: - Main Algorithm
class IMUAlgorithm {
    private let motionManager = CMMotionManager()
    private var kalmanPitch = KalmanFilter(initialEstimate: 0, initialErrorCovariance: 1, processNoise: 0.01, measurementNoise: 0.1)
    private var kalmanRoll = KalmanFilter(initialEstimate: 0, initialErrorCovariance: 1, processNoise: 0.01, measurementNoise: 0.1)
    private var kalmanHeading = KalmanFilter(initialEstimate: 0, initialErrorCovariance: 1, processNoise: 0.01, measurementNoise: 0.1)

    private var lastStepTimestamp: TimeInterval = 0
    private let stepDetectionThreshold: Double = 1.2
    private let minStepInterval: TimeInterval = 0.3 // Minimo tempo tra passi

    var imuState = IMUState(pitch: 0, roll: 0, heading: 0, position: (x: 0, y: 0))

    init() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.01 // Aggiornamenti ogni 10ms
        }
    }

    func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion non disponibile.")
            return
        }

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] deviceMotion, error in
            guard let self = self, let deviceMotion = deviceMotion else { return }

            // Crea i dati dei sensori
            let sensorData = SensorData(
                accelerometer: deviceMotion.userAcceleration,
                gyroscope: deviceMotion.rotationRate,
                magnetometer: deviceMotion.magneticField.field
            )

            // Calcola deltaTime
            let currentTime = Date().timeIntervalSince1970
            let deltaTime = currentTime - self.lastStepTimestamp

            // Aggiorna lo stato dell'IMU
            self.updateIMUState(sensorData: sensorData, deltaTime: deltaTime)
        }
    }

    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func updateIMUState(sensorData: SensorData, deltaTime: TimeInterval) {
        // Calcola pitch e roll
        let (pitch, roll) = calculatePitchRoll(
            accelerometer: sensorData.accelerometer,
            gyroscope: sensorData.gyroscope
        )

        // Calcola heading
        let heading = calculateHeading(magnetometer: sensorData.magnetometer)

        // Rileva passi e aggiorna posizione
        if detectSteps(accelerometer: sensorData.accelerometer, deltaTime: deltaTime) {
            imuState.position = estimatePosition(
                currentPosition: imuState.position,
                heading: heading,
                stepLength: 0.75
            )
        }

        // Aggiorna lo stato
        imuState.pitch = pitch
        imuState.roll = roll
        imuState.heading = heading

        // Debug
        print("Pitch: \(pitch), Roll: \(roll), Heading: \(heading), Position: \(imuState.position)")
    }

    private func calculatePitchRoll(accelerometer: CMAcceleration, gyroscope: CMRotationRate) -> (Double, Double) {
        // Calcola pitch e roll dall'accelerometro
        let pitchAcc = atan2(accelerometer.y, accelerometer.z) * 180 / .pi
        let rollAcc = atan2(accelerometer.x, accelerometer.z) * 180 / .pi

        // Filtra con Kalman
        let pitch = kalmanPitch.update(measurement: pitchAcc)
        let roll = kalmanRoll.update(measurement: rollAcc)

        return (pitch, roll)
    }

    private func detectSteps(accelerometer: CMAcceleration, deltaTime: TimeInterval) -> Bool {
        let currentTime = Date().timeIntervalSince1970
        let isStep = abs(accelerometer.z) > stepDetectionThreshold && (currentTime - lastStepTimestamp) > minStepInterval

        if isStep {
            lastStepTimestamp = currentTime
        }

        return isStep
    }

    private func calculateHeading(magnetometer: CMMagneticField) -> Double {
        // Calcola heading dal magnetometro
        let headingMag = atan2(magnetometer.y, magnetometer.x) * 180 / .pi

        // Filtra con Kalman
        return kalmanHeading.update(measurement: headingMag)
    }

    private func estimatePosition(currentPosition: (x: Double, y: Double), heading: Double, stepLength: Double) -> (Double, Double) {
        // Calcola la nuova posizione usando heading e lunghezza del passo
        let radHeading = heading * .pi / 180
        let newX = currentPosition.x + stepLength * cos(radHeading)
        let newY = currentPosition.y + stepLength * sin(radHeading)
        return (newX, newY)
    }
}
