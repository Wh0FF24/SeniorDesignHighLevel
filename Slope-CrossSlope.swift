import SwiftUI
import CoreMotion

// MotionManager to handle motion updates and calculations
class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    private let alpha: Double = 0.1
    private var smoothedPitch: Double = 0.0
    private var smoothedRoll: Double = 0.0
    
    private var baselinePitch: Double = 0.0
    private var baselineRoll: Double = 0.0
    
    // Public computed properties to access smoothed values
    var smoothedPitchInDegrees: Double {
        smoothedPitch
    }
    
    var smoothedRollInDegrees: Double {
        smoothedRoll
    }
    
    // Computed properties for pitchGrade and pitchRoll

    var pitchGrade: Double {
        // Convert pitch from degrees to radians and use the tangent
        // Tangent of the angle gives the slope, which can be converted to a percentage
        let pitchRadians = smoothedPitch * .pi / 180
        return tan(pitchRadians) * 100 // Convert to percentage
    }
    
    var rollGrade: Double {
        // Convert roll from degrees to radians and use the tangent
        let rollRadians = smoothedRoll * .pi / 180
        return tan(rollRadians) * 100 // Convert to percentage
    }
    
    init() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion else { return }
                
                let orientation = UIDevice.current.orientation
                var newPitch = motion.attitude.pitch * (180 / .pi)
                var newRoll = motion.attitude.roll * (180 / .pi)
                
                // Adjusting the pitch and roll based on the device orientation
                switch orientation {
                case .landscapeLeft:
                    swap(&newPitch, &newRoll)
                    newRoll = -newRoll
                case .landscapeRight:
                    swap(&newPitch, &newRoll)
                    newPitch = -newPitch
                case .portraitUpsideDown:
                    newPitch = -newPitch
                    newRoll = -newRoll
                default:
                    break
                }
                
                // Smoothing the pitch and roll values
                DispatchQueue.main.async {
                    self.smoothedPitch = (1 - self.alpha) * self.smoothedPitch + self.alpha * newPitch
                    self.smoothedRoll = (1 - self.alpha) * self.smoothedRoll + self.alpha * newRoll
                    self.pitch = self.smoothedPitch - self.baselinePitch
                    self.roll = self.smoothedRoll - self.baselineRoll
                }
            }
        }
    }
    
    // Function to set the current smoothed values as baseline
    func setBaseline() {
        DispatchQueue.main.async {
            self.baselinePitch = self.smoothedPitch
            self.baselineRoll = self.smoothedRoll
        }
    }
}

// SwiftUI View to display slope measurements
struct SlopeMeasurementView: View {
    @ObservedObject var motionManager = MotionManager()
    
    var body: some View {
        VStack(spacing: 30) {
            SlopeInfoView(title: "Slope (Camera to Charging port)", value: motionManager.pitch, angle: motionManager.smoothedPitchInDegrees, color: .green, unit: "% Grade")
            SlopeInfoView(title: "Cross Slope (Button to Button)", value: motionManager.roll, angle: motionManager.smoothedRollInDegrees, color: .blue, unit: "% Grade")
            
            Button("Set Zero Reference") {
                motionManager.setBaseline()
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .padding(.top, 50)
        }
    }
}

// Subview to display individual slope information
struct SlopeInfoView: View {
    var title: String
    var value: Double
    var angle: Double
    var color: Color
    var unit: String
    
    var body: some View {
        VStack {
            Text(title).font(.headline)
            GaugeView(value: value, color: color).frame(height: 100)
            Text("\(value, specifier: "%.2f") \(unit)").font(.largeTitle).fontWeight(.bold).foregroundColor(color)
            Text("\(angle, specifier: "%.2f")°").font(.title2).foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white).shadow(color: .gray, radius: 5, x: 0, y: 2))
    }
}

// Gauge view to visually represent the slope value
struct GaugeView: View {
    var value: Double
    var color: Color
    
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.5).stroke(lineWidth: 15).rotationEffect(Angle(degrees: 180)).foregroundColor(.gray.opacity(0.2))
            Circle().trim(from: 0, to: CGFloat((value + 90) / 180)).stroke(lineWidth: 15).rotationEffect(Angle(degrees: 180)).foregroundColor(color)
        }
    }
}
