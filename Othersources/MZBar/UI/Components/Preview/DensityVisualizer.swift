import SwiftUI

struct DensityVisualizer: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let gridWidth = cardWidth * 0.8
            let spacing: CGFloat = 2
            let gridSize = Int(viewModel.previewDensity * 5)
            
            let (rectangleWidth, rectangleHeight) = calculateRectangleDimensions(
                gridWidth: gridWidth,
                gridSize: gridSize,
                spacing: spacing,
                aspectRatio: viewModel.selectedAspectRatio.ratio,
                desiredGridHeight: 80
            )
            
            HStack(spacing: spacing) {
                ForEach(0..<gridSize, id: \.self) { _ in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [
                                viewModel.currentTheme.colors.primary,
                                viewModel.currentTheme.colors.accent
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .opacity(0.1 + 0.1 * viewModel.previewDensity)
                        .frame(width: rectangleWidth, height: rectangleHeight)
                        .cornerRadius(2)
                }
            }
            .frame(width: gridWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 100)
    }
    
    private func calculateRectangleDimensions(
        gridWidth: CGFloat,
        gridSize: Int,
        spacing: CGFloat,
        aspectRatio: CGFloat,
        desiredGridHeight: CGFloat
    ) -> (width: CGFloat, height: CGFloat) {
        let totalSpacing = spacing * CGFloat(gridSize - 1)
        let availableWidth = gridWidth - totalSpacing
        
        if aspectRatio >= 1 {
            let width = min((availableWidth / CGFloat(gridSize)), desiredGridHeight * aspectRatio)
            let height = width / aspectRatio
            return (width, height)
        } else {
            let height = desiredGridHeight
            let width = height * aspectRatio
            return (width, height)
        }
    }
} 