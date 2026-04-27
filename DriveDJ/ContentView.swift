import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = DriveDJViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    debugText
                    statusCard
                    driveControls
                    actionButtons
                    trackList
                }
                .padding()
            }
            .navigationTitle("DriveDJ")
            .task {
                try? await viewModel.bootstrap()
                try? await viewModel.refreshSetlist()
            }
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                viewModel.tick()
            }
        }
    }
    private var debugText: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(DriveDJViewModel.debugText)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Now")
                .font(.headline)

            Text("Mood: \(viewModel.snapshot.mood.rawValue)")
                .font(.title3.bold())

            Text("Track: \(viewModel.snapshot.currentTitle)")
            Text("Artist: \(viewModel.snapshot.currentArtist)")
            Text("Queue: \(viewModel.snapshot.queueCount)")
            Text("Status: \(viewModel.snapshot.status)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var driveControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drive state").font(.headline)

            metricRow(title: "Source", value: viewModel.session.isCarPlayConnected ? "CarPlay + Location" : "iPhone Location")
            metricRow(title: "Speed", value: "\(Int(viewModel.session.speedKPH)) km/h")

            Toggle("Night", isOn: $viewModel.session.isNight)

            metricRow(title: "Route", value: String(format: "%.2f", viewModel.session.routeIntensity))
            metricRow(title: "City", value: String(format: "%.2f", viewModel.session.cityDensity))
            metricRow(title: "Weather", value: viewModel.session.weather.condition)
            metricRow(title: "Temp", value: temperatureText)
            metricRow(title: "Rain", value: precipitationText)
            metricRow(title: "Wind", value: windText)
            metricRow(title: "Weather score", value: String(format: "%.2f", viewModel.session.weather.severity))

            HStack {
                Text("Trip mins")
                Slider(value: $viewModel.session.tripDurationMinutes, in: 5...180, step: 1)
                Text("\(Int(viewModel.session.tripDurationMinutes))")
                    .frame(width: 70, alignment: .trailing)
                    .monospacedDigit()
            }

            HStack {
                Text("Elapsed")
                Text("\(Int(viewModel.session.elapsedMinutes))")
                    .monospacedDigit()
                Spacer()
                Text("Remaining \(Int(viewModel.session.remainingMinutes))")
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var actionButtons: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                Button("Refresh Setlist") {
                    Task { try? await viewModel.refreshSetlist() }
                }
                .buttonStyle(.borderedProminent)

                Button(viewModel.session.isTripRunning ? "Stop Trip" : "Start Trip") {
                    viewModel.toggleTrip()
                }
                .buttonStyle(.bordered)
            }

            GridRow {
                Button("Enrich From APIs") {
                    Task { await viewModel.enrichLibrary() }
                }
                .buttonStyle(.bordered)

                Button("Play Queue") {
                    Task { await viewModel.playPreparedSetlist() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var trackList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming").font(.headline)
            ForEach(viewModel.upcomingTracks) { track in
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.subheadline.bold())
                    Text(track.artist).font(.footnote).foregroundStyle(.secondary)
                    Text(meta(track))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var temperatureText: String {
        guard let value = viewModel.session.weather.temperatureC else { return "—" }
        return String(format: "%.0f C", value)
    }

    private var precipitationText: String {
        guard let value = viewModel.session.weather.precipitationKPH else { return "—" }
        return String(format: "%.1f km/h", value)
    }

    private var windText: String {
        guard let value = viewModel.session.weather.windKPH else { return "—" }
        return String(format: "%.0f km/h", value)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func meta(_ track: TrackRecord) -> String {
        let bpm = track.bpm.map { String(format: "%.0f BPM", $0) } ?? "BPM —"
        let energy = track.energy.map { String(format: "energy %.2f", $0) } ?? "energy —"
        let valence = track.valence.map { String(format: "valence %.2f", $0) } ?? "valence —"
        return [bpm, energy, valence, track.tags.joined(separator: ", ")].joined(separator: " • ")
    }
}
