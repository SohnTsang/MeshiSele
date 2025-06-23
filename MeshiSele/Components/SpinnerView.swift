import SwiftUI

struct SpinnerView: View {
    @Binding var isSpinning: Bool
    @State private var rotationAngle: Double = 0
    
    let sections: [SpinnerSection] = [
        SpinnerSection(color: .red, text: "和食"),
        SpinnerSection(color: .green, text: "洋食"),
        SpinnerSection(color: .orange, text: "中華"),
        SpinnerSection(color: .purple, text: "イタリアン"),
        SpinnerSection(color: .blue, text: "すべて"),
        SpinnerSection(color: .yellow, text: "その他")
    ]
    
    var body: some View {
        ZStack {
            // Spinner wheel
            ZStack {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    SpinnerSectionView(
                        section: section,
                        startAngle: Double(index) * 60,
                        endAngle: Double(index + 1) * 60
                    )
                }
            }
            .rotationEffect(.degrees(rotationAngle))
            .animation(
                isSpinning ? 
                .easeOut(duration: 3.0) :
                .none,
                value: rotationAngle
            )
            
            // Center circle
            Circle()
                .fill(Color.white)
                .frame(width: 40, height: 40)
                .shadow(radius: 4)
            
            // Pointer
            VStack {
                Triangle()
                    .fill(Color.black)
                    .frame(width: 20, height: 30)
                Spacer()
            }
            .offset(y: -10)
        }
        .frame(width: 200, height: 200)
        .onChange(of: isSpinning) { newValue in
            if newValue {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    rotationAngle += 360
                }
            } else {
                withAnimation(.none) {
                    rotationAngle = 0
                }
            }
        }
    }
    
    private func startSpinning() {
        let randomRotation = Double.random(in: 720...1440) // 2-4 full rotations
        rotationAngle += randomRotation
    }
}

struct SpinnerSection {
    let color: Color
    let text: String
}

struct SpinnerSectionView: View {
    let section: SpinnerSection
    let startAngle: Double
    let endAngle: Double
    
    var body: some View {
        ZStack {
            // Section background
            Path { path in
                let center = CGPoint(x: 100, y: 100)
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: 100,
                    startAngle: .degrees(startAngle - 90),
                    endAngle: .degrees(endAngle - 90),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .foregroundColor(section.color.opacity(0.8))
            .overlay(
                Path { path in
                    let center = CGPoint(x: 100, y: 100)
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: 100,
                        startAngle: .degrees(startAngle - 90),
                        endAngle: .degrees(endAngle - 90),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .stroke(Color.white, lineWidth: 2)
            )
            
            // Section text
            Text(section.text)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .rotationEffect(.degrees(startAngle + 30 - 90))
                .offset(
                    x: cos(.degrees(startAngle + 30 - 90)) * 60,
                    y: sin(.degrees(startAngle + 30 - 90)) * 60
                )
        }
        .frame(width: 200, height: 200)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        
        return path
    }
}

// Extension for angle calculations
extension Angle {
    static func degrees(_ value: Double) -> Angle {
        return Angle(degrees: value)
    }
}

extension Double {
    var radians: Double {
        return self * .pi / 180
    }
}

func cos(_ angle: Angle) -> Double {
    return Darwin.cos(angle.radians)
}

func sin(_ angle: Angle) -> Double {
    return Darwin.sin(angle.radians)
}

struct SpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        SpinnerView(isSpinning: .constant(false))
    }
} 