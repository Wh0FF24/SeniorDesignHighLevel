import MapKit

class GradientPolylineRenderer: MKOverlayPathRenderer {
    var polyline: MKPolyline
    var gradientColors: [UIColor]
    
    init(polyline: MKPolyline, gradientColors: [UIColor]) {
        self.polyline = polyline
        self.gradientColors = gradientColors
        super.init(overlay: polyline)
    }
    
    override func createPath() {
        let path = CGMutablePath()
        var pathPoints = [CGPoint]()
        
        // Convert polyline points to CGPoint array
        for i in 0..<polyline.pointCount {
            let point = self.point(for: polyline.points()[i])
            pathPoints.append(point)
        }
        
        // Create path from points
        path.addLines(between: pathPoints)
        self.path = path
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let path = self.path else { return }
        
        context.addPath(path)
        context.setLineWidth(self.lineWidth / zoomScale)
        context.replacePathWithStrokedPath()
        context.clip()
        
        // Draw gradient
        let gradientLocations: [CGFloat] = [0, 1]
        let cgColors = gradientColors.map { $0.cgColor } as CFArray
        if let gradient = CGGradient(colorsSpace: nil, colors: cgColors, locations: gradientLocations) {
            let startPoint = path.boundingBox.origin
            let endPoint = CGPoint(x: path.boundingBox.maxX, y: path.boundingBox.maxY)
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
    }
}

extension GradientPolylineRenderer {
    
    // Calculate gradient colors based on slope percentage
    static func gradientColorsForSlope(slope: Double) -> [UIColor] {
        // Define the start and end colors for slope: Green (0%) to Red (5%)
        let startColorSlope = UIColor.green
        let endColorSlope = UIColor.red
        
        // Normalize slope value to a 0 to 1 scale for interpolation
        let normalizedSlope = min(max(slope / 5.0, 0), 1) // Ensures value is between 0 and 1
        
        // Calculate the interpolated color for slope
        let slopeColor = interpolateColor(from: startColorSlope, to: endColorSlope, with: normalizedSlope)
        
        return [slopeColor]
    }
    
    // Calculate gradient colors based on cross slope percentage
    static func gradientColorsForCrossSlope(crossSlope: Double) -> [UIColor] {
        // Define the start and end colors for cross slope: Dark Blue (0%) to Pink (2%)
        let startColorCrossSlope = UIColor(red: 0, green: 0, blue: 0.5, alpha: 1) // Dark Blue
        let endColorCrossSlope = UIColor.systemPink
        
        // Normalize cross slope value to a 0 to 1 scale for interpolation
        let normalizedCrossSlope = min(max(crossSlope / 2.0, 0), 1) // Ensures value is between 0 and 1
        
        // Calculate the interpolated color for cross slope
        let crossSlopeColor = interpolateColor(from: startColorCrossSlope, to: endColorCrossSlope, with: normalizedCrossSlope)
        
        return [crossSlopeColor]
    }
    
    // Interpolate between two colors based on a given factor
    private static func interpolateColor(from startColor: UIColor, to endColor: UIColor, with factor: CGFloat) -> UIColor {
        var startRed: CGFloat = 0, startGreen: CGFloat = 0, startBlue: CGFloat = 0, startAlpha: CGFloat = 0
        startColor.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha)
        
        var endRed: CGFloat = 0, endGreen: CGFloat = 0, endBlue: CGFloat = 0, endAlpha: CGFloat = 0
        endColor.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha)
        
        // Interpolate the components
        let red = startRed + (endRed - startRed) * factor
        let green = startGreen + (endGreen - startGreen) * factor
        let blue = startBlue + (endBlue - startBlue) * factor
        let alpha = startAlpha + (endAlpha - startAlpha) * factor
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
