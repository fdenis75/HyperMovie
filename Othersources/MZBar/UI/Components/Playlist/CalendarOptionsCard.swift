import SwiftUI

struct CalendarOptionsCard: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        SettingsCard(title: "Calendar Options", icon: "calendar", viewModel: viewModel) {
            VStack(spacing: 16) {
                DatePicker("Start Date", 
                    selection: $viewModel.startDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                
                DatePicker("End Date",
                    selection: $viewModel.endDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
            }
            .padding(.vertical, 8)
        }
    }
} 