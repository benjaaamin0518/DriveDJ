import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = DriveDJViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    heroCard
                    tripOverview
                    controlsPanel
                    queuePanel
                    debugPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 24)
            }
            .background(backgroundGradient)
            .navigationTitle("Drive DJ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.08, green: 0.12, blue: 0.16), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                try? await viewModel.bootstrap()
                try? await viewModel.refreshSetlist()
            }
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                viewModel.tick()
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.12, blue: 0.16),
                Color(red: 0.14, green: 0.18, blue: 0.20),
                Color(red: 0.56, green: 0.34, blue: 0.19)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ドライブに合わせて選曲")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.82))

                    Text(viewModel.snapshot.mood.rawValue)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(viewModel.snapshot.status)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    statPill(title: "再生元", value: viewModel.session.isCarPlayConnected ? "CarPlay" : "iPhone")
                    statPill(title: "キュー", value: "\(viewModel.snapshot.queueCount)")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.snapshot.currentTitle)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(viewModel.snapshot.currentArtist)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                summaryBadge(systemName: "speedometer", text: "\(Int(viewModel.session.speedKPH)) km/h")
                summaryBadge(systemName: "cloud.sun", text: viewModel.session.weather.condition)
                summaryBadge(systemName: "clock", text: "残り \(Int(viewModel.session.remainingMinutes)) 分")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.19).opacity(0.96),
                    Color(red: 0.16, green: 0.24, blue: 0.26).opacity(0.94),
                    Color(red: 0.58, green: 0.35, blue: 0.20).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 10)
    }

    private var tripOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("ドライブ状態")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricTile(title: "ルート強度", value: String(format: "%.2f", viewModel.session.routeIntensity), systemName: "point.topleft.down.curvedto.point.bottomright.up")
                metricTile(title: "街中密度", value: String(format: "%.2f", viewModel.session.cityDensity), systemName: "building.2")
                metricTile(title: "気温", value: temperatureText, systemName: "thermometer.medium")
                metricTile(title: "天候スコア", value: String(format: "%.2f", viewModel.session.weather.severity), systemName: "cloud.rain")
            }

            VStack(spacing: 12) {
                metricRow(title: "天気", value: viewModel.session.weather.condition)
                metricRow(title: "降水", value: precipitationText)
                metricRow(title: "風速", value: windText)

                Toggle(isOn: $viewModel.session.isNight) {
                    Text("夜間ドライブ")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .tint(Color(red: 0.96, green: 0.56, blue: 0.29))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ドライブ時間")
                        Spacer()
                        Text("\(Int(viewModel.session.tripDurationMinutes)) 分")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                    Slider(value: $viewModel.session.tripDurationMinutes, in: 5...180, step: 1)
                        .tint(Color(red: 0.12, green: 0.55, blue: 0.64))
                }

                HStack {
                    timelinePill(title: "経過", value: "\(Int(viewModel.session.elapsedMinutes))分")
                    timelinePill(title: "残り", value: "\(Int(viewModel.session.remainingMinutes))分")
                }
            }
        }
        .padding(20)
        .panelBackground()
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("操作")

            VStack(spacing: 12) {
                actionButton(
                    title: viewModel.session.isTripRunning ? "ドライブ終了" : "ドライブ開始",
                    subtitle: viewModel.session.isTripRunning ? "位置情報に連動した更新を止めます" : "走行状況に応じたセッションを始めます",
                    systemName: viewModel.session.isTripRunning ? "pause.circle.fill" : "play.circle.fill",
                    accent: Color(red: 0.96, green: 0.56, blue: 0.29)
                ) {
                    viewModel.toggleTrip()
                }

                actionButton(
                    title: "キューを再生",
                    subtitle: "新しい候補を取得して再生候補を更新します",
                    systemName: "music.note.list",
                    accent: Color(red: 0.12, green: 0.55, blue: 0.64)
                ) {
                    Task { await viewModel.playPreparedSetlist() }
                }

                HStack(spacing: 12) {
                    secondaryActionButton(title: "候補を更新", systemName: "arrow.clockwise") {
                        Task { try? await viewModel.refreshSetlist() }
                    }

                    secondaryActionButton(title: "API補完", systemName: "sparkles") {
                    }
                }
            }
        }
        .padding(20)
        .panelBackground()
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("次に流す曲")
                Spacer()
                Text("\(viewModel.upcomingTracks.count) 曲")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            if viewModel.upcomingTracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("まだ候補曲がありません")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("ドライブを開始するか、キュー再生で候補曲を作成してください。")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ForEach(Array(viewModel.upcomingTracks.enumerated()), id: \.element.id) { index, track in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.93, green: 0.51, blue: 0.24).opacity(0.12))
                                .frame(width: 54, height: 54)
                            Text("\(index + 1)")
                                .font(.system(.headline, design: .rounded, weight: .black))
                                .foregroundStyle(Color(red: 0.73, green: 0.30, blue: 0.12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(track.title)
                                .font(.system(.headline, design: .serif, weight: .bold))
                                .lineLimit(2)

                            Text(track.artist)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text(meta(track))
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .padding(20)
        .panelBackground()
    }

    private var debugPanel: some View {
        Group {
            if !DriveDJViewModel.debugText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("解決ログ")
                    Text(DriveDJViewModel.debugText)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Color(red: 0.22, green: 0.26, blue: 0.30))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .panelBackground()
            }
        }
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(Color(red: 0.10, green: 0.17, blue: 0.18))
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func summaryBadge(systemName: String, text: String) -> some View {
        Label(text, systemImage: systemName)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.10), in: Capsule())
            .lineLimit(1)
    }

    private func metricTile(title: String, value: String, systemName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.14, green: 0.56, blue: 0.63))

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(Color(red: 0.11, green: 0.16, blue: 0.18))

            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.24, green: 0.29, blue: 0.33))
                .font(.system(.subheadline, design: .rounded, weight: .medium))
        }
    }

    private func timelinePill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.10, green: 0.17, blue: 0.18))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionButton(
        title: String,
        subtitle: String,
        systemName: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: systemName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.17, blue: 0.18))
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Color(red: 0.28, green: 0.33, blue: 0.37))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondaryActionButton(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemName)
                Text(title)
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(Color(red: 0.10, green: 0.17, blue: 0.18))
        }
        .buttonStyle(.plain)
    }

    private func meta(_ track: TrackRecord) -> String {
        let bpm = track.bpm.map { String(format: "%.0f BPM", $0) } ?? "BPM —"
        let energy = track.energy.map { String(format: "energy %.2f", $0) } ?? "energy —"
        let valence = track.valence.map { String(format: "valence %.2f", $0) } ?? "valence —"
        return [bpm, energy, valence, track.tags.joined(separator: ", ")].joined(separator: " • ")
    }
}

private extension View {
    func panelBackground() -> some View {
        background(
            Color.white.opacity(0.96),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}
