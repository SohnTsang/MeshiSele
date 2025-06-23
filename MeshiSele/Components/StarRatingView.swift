import SwiftUI

struct StarRatingView: View {
    let rating: Double
    let maxRating: Int
    let size: CGFloat
    let isInteractive: Bool
    let onRatingChanged: ((Double) -> Void)?
    
    init(rating: Double, maxRating: Int = 5, size: CGFloat = 16, isInteractive: Bool = false, onRatingChanged: ((Double) -> Void)? = nil) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
        self.isInteractive = isInteractive
        self.onRatingChanged = onRatingChanged
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Button(action: {
                    if isInteractive {
                        onRatingChanged?(Double(index))
                    }
                }) {
                    Image(systemName: starType(for: index))
                        .font(.system(size: size))
                        .foregroundColor(starColor(for: index))
                }
                .disabled(!isInteractive)
            }
            
            if rating > 0 {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: size - 2))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
    
    private func starType(for index: Int) -> String {
        let difference = rating - Double(index - 1)
        
        if difference >= 1.0 {
            return "star.fill"
        } else if difference >= 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for index: Int) -> Color {
        let difference = rating - Double(index - 1)
        
        if difference >= 0.5 {
            return .yellow
        } else if isInteractive {
            return .gray.opacity(0.5)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

struct InteractiveStarRatingView: View {
    @Binding var rating: Int
    let maxRating: Int = 5
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxRating, id: \.self) { index in
                Button(action: {
                    rating = index
                }) {
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundColor(index <= rating ? .yellow : .gray)
                }
            }
        }
    }
}

struct StarRatingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StarRatingView(rating: 3.5)
            StarRatingView(rating: 4.2, maxRating: 5, size: 20, isInteractive: false)
            StarRatingView(rating: 2.0, maxRating: 5, size: 16, isInteractive: true) { newRating in
                print("New rating: \(newRating)")
            }
            InteractiveStarRatingView(rating: .constant(4))
        }
        .padding()
    }
} 