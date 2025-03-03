import SwiftUI

struct ContentView: View {
    @StateObject public var viewModel = MosaicViewModel()
    @State private var receivedUrls: [URL] = []
    var body: some View {
        ZStack {
            // Vibrant Background
            BackgroundView(viewModel: viewModel)
            .ignoresSafeArea()
            
            NavigationSplitView {
                SidebarView(viewModel: viewModel)
                    .frame(alignment: .center)
                    .frame(width: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .containerBackground(.blue.opacity(0.3), for: .window)
                    
            } detail: {
                DetailView(viewModel: viewModel)
            }
            .onAppear {
                if viewModel.selectedMode == nil {
                    viewModel.selectedMode = .mosaic
                }
            }
           
        }
    }
}

private struct BackgroundView: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        ZStack {
            Color.gray
                .opacity(0.25)
                .ignoresSafeArea()
            
            Color.white
                .opacity(0.7)
                .blur(radius: 200)
                .ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                
                Circle()
                    .fill(viewModel.currentTheme.colors.primary)
                    .padding(50)
                    .blur(radius: 120)
                    .offset(x: -size.width/1.8, y: -size.height/5)
                
                Circle()
                    .fill(viewModel.currentTheme.colors.accent)
                    .padding(50)
                    .blur(radius: 150)
                    .offset(x: size.width/1.8, y: size.height/2)
            }
        }
    }
}

#Preview {
    ContentView()
} 
