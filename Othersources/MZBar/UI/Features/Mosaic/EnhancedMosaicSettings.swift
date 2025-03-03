//
//  File.swift
//  MZBar
//
//  Created by Francois on 24/12/2024.
//
import SwiftUI

struct EnhancedMosaicSettings: View {
  @ObservedObject var viewModel: MosaicViewModel
  @State private var isEditing2 = false

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
      // Landscape or square
      let width = min((availableWidth / CGFloat(gridSize)), desiredGridHeight * aspectRatio)
      let height = width / aspectRatio
      return (width, height)
    } else {
      // Portrait
      let height = desiredGridHeight
      let width = height * aspectRatio
      return (width, height)
    }
  }

  // Add this helper function to EnhancedMosaicSettings:
  private func getPresetColor(_ preset: String) -> Float {
    switch preset {
    case "Low": return 0.3
    case "Medium": return 0.6
    case "High": return 0.9
    default: return 0.6
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Drop Zone
        EnhancedDropZone(
          viewModel: viewModel, inputPaths: $viewModel.inputPaths, inputType: $viewModel.inputType
        )
        .frame(maxWidth: .infinity)

        // Main Settings Card (Size, Density, Duration)
        SettingsCard(title: "Configuration", icon: "slider.horizontal.3", viewModel: viewModel) {
          VStack(spacing: 16) {
            // Auto Layout Toggle
            Toggle(isOn: $viewModel.isAutoLayout) {
              Label("Auto Layout", systemImage: "rectangle.3.group")
                .foregroundStyle(viewModel.currentTheme.colors.primary)
            }
            .toggleStyle(.switch)

            if !viewModel.isAutoLayout {
              // Aspect Ratio Selector
              HStack {
                VStack(alignment: .leading, spacing: 8) {
                  Label("Aspect Ratio", systemImage: "aspectratio")
                    .foregroundStyle(viewModel.currentTheme.colors.primary)
                SegmentedPicker(selection: $viewModel.selectedAspectRatio, options: MosaicViewModel.MosaicAspectRatio.allCases) {
                    ratio in
                    Text("\(ratio.rawValue)")
                  }
                }
              // Size Section
                VStack(alignment: .leading, spacing: 8) {
                  Label("Output Size", systemImage: "ruler")
                    .foregroundStyle(viewModel.currentTheme.colors.primary)
                  SegmentedPicker(selection: $viewModel.selectedSize, options: viewModel.sizes) {
                    size in
                    Text("\(size)px")
                  }
                }
              }
              Divider()
                .background(viewModel.currentTheme.colors.primary.opacity(0.2))

              // Density Section
              VStack(alignment: .leading, spacing: 12) {
                Label("Density", systemImage: "chart.bar.fill")
                  .foregroundStyle(viewModel.currentTheme.colors.primary)

                // Density Grid
                GeometryReader { geometry in
                  let cardWidth = geometry.size.width
                  let gridWidth = cardWidth * 0.8
                  let spacing: CGFloat = 2
                  let gridSize = Int(sqrt(Double(Int(viewModel.selectedDensity * 10))))
                  let desiredGridHeight: CGFloat = 80
                  let rectangleHeight =
                    (desiredGridHeight - (spacing * CGFloat(gridSize - 1))) / CGFloat(gridSize)
                  let rectangleWidth = rectangleHeight * viewModel.selectedAspectRatio.ratio

                  LazyVGrid(
                    columns: Array(
                      repeating: GridItem(.fixed(rectangleWidth), spacing: spacing), count: gridSize
                    ),
                    spacing: spacing
                  ) {
                    ForEach(0..<(gridSize * gridSize), id: \.self) { _ in
                      Rectangle()
                        .fill(
                          LinearGradient(
                            colors: [
                              viewModel.currentTheme.colors.primary,
                              viewModel.currentTheme.colors.accent,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                        )
                        .opacity(0.1 + 0.1 * viewModel.selectedDensity)
                        .frame(width: rectangleWidth, height: rectangleHeight)
                        .cornerRadius(2)
                    }
                  }
                  .frame(width: gridWidth)
                  .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 100)

                // Density Controls
                HStack(spacing: 8) {
                  ForEach(["XXS", "XS", "S", "M", "L", "XL", "XXL"], id: \.self) { label in
                    Button {
                      withAnimation {
                        viewModel.selectedDensity = Double(densityValue(for: label))
                      }
                    } label: {
                      Text(label)
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(
                      viewModel.selectedDensity == Double(densityValue(for: label))
                        ? viewModel.currentTheme.colors.primary : .secondary)
                  }
                }.frame(maxWidth: .infinity, alignment: .center)
              }

             

              Divider()
                .background(viewModel.currentTheme.colors.primary.opacity(0.2))

              // Duration Section
              VStack(alignment: .leading, spacing: 8) {
                Label("Minimum Duration", systemImage: "clock.fill")
                  .foregroundStyle(viewModel.currentTheme.colors.primary)
                DurationPicker(selection: $viewModel.selectedduration)
                  .tint(viewModel.currentTheme.colors.primary)
              }.frame(maxWidth: .infinity)
                .padding(.vertical, 8)

              // Thumbnail Effects Section
              VStack(alignment: .leading, spacing: 8) {
                Label("Thumbnail Effects", systemImage: "wand.and.stars")
                  .foregroundStyle(viewModel.currentTheme.colors.primary)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                  GridRow {
                    OptionToggle("Add Border", icon: "square", isOn: $viewModel.addBorder)
                    OptionToggle("Add Shadow", icon: "drop.fill", isOn: $viewModel.addShadow)
                  }
                }

                // Border Controls (only show when border is enabled)
                if viewModel.addBorder {
                  VStack(alignment: .leading, spacing: 8) {
                    // Border Color
                    HStack {
                      Text("Border Color")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                      ColorPicker("", selection: $viewModel.borderColor)
                        .labelsHidden()
                    }

                    // Border Width
                    VStack(alignment: .leading, spacing: 4) {
                      HStack {
                        Text("Border Width")
                          .font(.subheadline)
                          .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.borderWidth))px")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }

                      Slider(
                        value: $viewModel.borderWidth,
                        in: 1...10,
                        step: 1
                      ) {
                        Text("Border Width")
                      } minimumValueLabel: {
                        Text("1")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      } maximumValueLabel: {
                        Text("10")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                      .tint(viewModel.currentTheme.colors.primary)
                    }
                  }
                  .padding(.top, 8)
                }
              }
              .padding(.vertical, 8)
            }
          }
        }
          // Output Settings Card (Format and Files)
          SettingsCard(title: "Output Settings", icon: "folder.fill", viewModel: viewModel) {
            VStack(spacing: 24) {
              // Format Section
              VStack(alignment: .leading, spacing: 8) {
                Label("Format", systemImage: "doc.fill")
                  .foregroundStyle(viewModel.currentTheme.colors.primary)
                FormatPicker(selection: $viewModel.selectedFormat)
              }

              Divider()
              VStack(alignment: .leading, spacing: 8) {
                Label("Output Quality", systemImage: "dial.high")
                  .foregroundStyle(viewModel.currentTheme.colors.primary)

                HStack {
                  Text("Quality: \(Int(viewModel.compressionQuality * 100))%")
                    .foregroundStyle(.secondary)
                  Spacer()
                }

                Slider(
                  value: $viewModel.compressionQuality,
                  in: 0.1...1.0,
                  step: 0.1
                ) {
                  Text("Quality")
                } minimumValueLabel: {
                  Text("Low")
                    .foregroundStyle(.secondary)
                } maximumValueLabel: {
                  Text("High")
                    .foregroundStyle(.secondary)
                }

                // Quality presets
                HStack(spacing: 8) {
                  ForEach(["Low", "Medium", "High"], id: \.self) { preset in
                    Button(action: {
                      withAnimation {
                        switch preset {
                        case "Low":
                          viewModel.compressionQuality = 0.3
                        case "Medium":
                          viewModel.compressionQuality = 0.6
                        case "High":
                          viewModel.compressionQuality = 0.9
                        default:
                          break
                        }
                      }
                    }) {
                      Text(preset)
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(
                      getPresetColor(preset) == viewModel.compressionQuality
                        ? viewModel.currentTheme.colors.primary : .gray)
                  }
                }.frame(maxWidth: .infinity, alignment: .center)
                  .padding(.top, 4)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)

              // Files Section
              VStack(alignment: .leading, spacing: 12) {
                Label("File Options", systemImage: "gear")
                  .foregroundStyle(viewModel.currentTheme.colors.primary)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                  GridRow {
                    OptionToggle(
                      "Overwrite", icon: "arrow.triangle.2.circlepath", isOn: $viewModel.overwrite)
                    OptionToggle("Save at Root", icon: "folder", isOn: $viewModel.saveAtRoot)
                    OptionToggle(
                      "Create folders by size", icon: "folder.badge.plus", isOn: $viewModel.seperate
                    )
                    OptionToggle(
                      "Add Full Path", icon: "text.alignleft", isOn: $viewModel.addFullPath)
                  }
                }
              }
            }
            .padding(.vertical, 8)
          }

          // Concurrency Card

          // Action Buttons
          HStack(spacing: 16) {
            Button {
              viewModel.processMosaics()
            } label: {
              HStack {
                Image(systemName: "square.grid.3x3.fill")
                Text("Generate Mosaic")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(viewModel.currentTheme.colors.primary)
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.inputPaths.isEmpty)

            Button {
              viewModel.generateMosaictoday()
            } label: {
              HStack {
                Image(systemName: "calendar")
                Text("Generate Today")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(.ultraThinMaterial)
              .foregroundColor(viewModel.currentTheme.colors.primary)
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .strokeBorder(viewModel.currentTheme.colors.primary, lineWidth: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
          }
          .padding(.top, 8)

          // Progress View
          //EnhancedProgressView(viewModel: viewModel)
        }
        .padding(12)
      }
    }

  private func densityValue(for label: String) -> Int {
    switch label {
    case "XXS": return 1
    case "XS": return 2
    case "S": return 3
    case "M": return 4
    case "L": return 5
    case "XL": return 6
    case "XXL": return 7
    default: return 4
    }
  }

}
