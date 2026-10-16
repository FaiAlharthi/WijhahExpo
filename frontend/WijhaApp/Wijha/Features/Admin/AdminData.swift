import SwiftUI

enum AdminEntity: String, CaseIterable, Identifiable, Hashable {
    case pavilions, zones, entrances, locations, paths, interests
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .pavilions: return "building.columns"
        case .zones: return "circle.hexagongrid"
        case .entrances: return "door.left.hand.open"
        case .locations: return "mappin.and.ellipse"
        case .paths: return "point.topleft.down.to.point.bottomright.curvepath"
        case .interests: return "heart"
        }
    }
}

// expo data (CRUD for zones, pavilions + accessibility + queue settings, gates, points, paths, interests)
struct AdminDataHome: View {
    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(s.t("admin.data")).font(WJFont.title1).foregroundStyle(Theme.textPrimary).padding(.top, 12)
                ForEach(AdminEntity.allCases) { entity in
                    NavigationLink(value: entity) {
                        HStack(spacing: 12) {
                            Image(systemName: entity.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.primaryText)
                                .frame(width: 40, height: 40)
                                .background(Theme.primarySoft, in: Circle())
                            Text(s.t("admin.entity.\(entity.rawValue)")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(count(entity))").font(WJFont.label.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary).flipsForRightToLeftLayoutDirection(true)
                        }
                        .card(padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await expo.load(force: true) }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: AdminEntity.self) { entity in
            switch entity {
            case .pavilions: AdminPavilionsView()
            case .zones: AdminZonesView()
            case .entrances: AdminEntrancesView()
            case .locations: AdminLocationsView()
            case .paths: AdminPathsView()
            case .interests: AdminInterestsView()
            }
        }
        .task { await expo.load(force: true) }
    }

    private func count(_ e: AdminEntity) -> Int {
        switch e {
        case .pavilions: return expo.pavilions.count
        case .zones: return expo.zones.count
        case .entrances: return expo.entrances.count
        case .locations: return expo.locations.count
        case .paths: return expo.paths.count
        case .interests: return expo.interests.count
        }
    }
}

// shared list scaffold: search, add, rows, delete confirm
struct AdminList<Item: Identifiable, Row: View>: View {
    let title: String
    let items: [Item]
    var searchText: (Item) -> String = { _ in "" }
    var onAdd: (() -> Void)?
    var onDelete: ((Item) async -> Void)?
    @ViewBuilder var row: (Item) -> Row
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var query = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
                    TextField(s.t("common.search"), text: $query)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                ForEach(filtered) { item in
                    row(item)
                        .contextMenu {
                            if let onDelete {
                                Button(role: .destructive) { confirm(item, onDelete) } label: { Label(s.t("common.delete"), systemImage: "trash") }
                            }
                        }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await expo.load(force: true) }
        .screenBackground()
        .wjTopBar(title) {
            if let onAdd {
                CircleIconButton(icon: "plus", size: 36, label: s.t("common.add"), action: onAdd)
            }
        }
    }

    private var filtered: [Item] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { searchText($0).localizedCaseInsensitiveContains(q) }
    }

    private func confirm(_ item: Item, _ action: @escaping (Item) async -> Void) {
        app.ask(DialogModel(icon: "trash", tone: .danger, title: s.t("admin.deleteTitle"), message: s.t("admin.deleteMessage"),
                            primary: s.t("common.delete"), primaryRole: .destructive, secondary: s.t("common.cancel"),
                            onPrimary: { Task { await action(item) } }))
    }
}

// row with a trailing delete button (long press also offers delete)
struct AdminRow<Content: View>: View {
    var onDelete: (() -> Void)?
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 10) {
            content()
            Spacer(minLength: 0)
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(Theme.danger).frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 12)
    }
}

// a form in a sheet: fields, error, save
struct AdminFormSheet<Fields: View>: View {
    let title: String
    var save: () async throws -> Void
    @ViewBuilder var fields: () -> Fields
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SheetHeader(title: title)
                    fields()
                    if let error { InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .danger) }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 16)
            }
            Button {
                Task {
                    saving = true
                    defer { saving = false }
                    do {
                        try await save()
                        await expo.load(force: true)
                        app.show(s.t("admin.saved"))
                        dismiss()
                    } catch {
                        self.error = AppState.message(error, s)
                    }
                }
            } label: {
                HStack { if saving { ProgressView().tint(.white) }; Text(s.t("common.save")) }
            }
            .buttonStyle(.wjPrimary)
            .disabled(saving)
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
        }
        .wjSheet([.large])
    }
}

// pick an existing location (point) for new zones, gates and pavilions
struct LocationPicker: View {
    let label: String
    @Binding var selection: Int?
    var onlyFree = true
    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(WJFont.label).foregroundStyle(Theme.textSecondary)
            Picker(label, selection: $selection) {
                Text(s.t("admin.chooseLocation")).tag(Int?.none)
                ForEach(options) { loc in
                    Text("#\(loc.id) · (\(Int(loc.x)), \(Int(loc.y)))").tag(Int?.some(loc.id))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: 48)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.borderStrong, lineWidth: 1))
        }
    }

    private var options: [LocationDTO] {
        guard onlyFree else { return expo.locations }
        var used = Set(expo.pavilions.compactMap { $0.location?.id })
        used.formUnion(expo.zones.compactMap { $0.location?.id })
        used.formUnion(expo.entrances.compactMap { $0.location?.id })
        return expo.locations.filter { !used.contains($0.id) }
    }
}

// ===== pavilions =====
struct AdminPavilionsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var editing: Pavilion?
    @State private var adding = false

    var body: some View {
        AdminList(title: s.t("admin.entity.pavilions"), items: expo.pavilions.sorted { $0.name < $1.name },
                  searchText: { "\($0.name) \(s.pavilionName($0.name)) \($0.country ?? "")" },
                  onAdd: { adding = true },
                  onDelete: { p in
                      do { try await API.deletePavilion(p.id); await expo.load(force: true) } catch { app.showError(error, s) }
                  }) { pavilion in
            NavigationLink {
                AdminPavilionDetail(pavilionId: pavilion.id)
            } label: {
                HStack(spacing: 12) {
                    RemoteImage(url: pavilion.imageUrl, cornerRadius: 10).frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.pavilionName(pavilion.name)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text("\(s.zoneTitle(expo.zone(of: pavilion.id)?.name)) · \(s.t("admin.capacityShort", "\(pavilion.capacity ?? 0)", "\(pavilion.avgVisitMinutes ?? 0)"))")
                            .font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary).flipsForRightToLeftLayoutDirection(true)
                }
                .card(padding: 12)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $adding) { PavilionForm(pavilion: nil) }
    }
}

struct AdminPavilionDetail: View {
    let pavilionId: Int
    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo
    @State private var details: PavilionDetails?
    @State private var editInfo = false
    @State private var editNeed: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let pavilion = expo.pavilion(pavilionId) {
                    RemoteImage(url: pavilion.imageUrl, cornerRadius: 18).frame(height: 170).frame(maxWidth: .infinity)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.pavilionName(pavilion.name)).font(WJFont.title2).foregroundStyle(Theme.textPrimary)
                            Text("\(s.countryName(pavilion.country)) · \(s.zoneTitle(expo.zone(of: pavilion.id)?.name))")
                                .font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button(s.t("common.edit")) { editInfo = true }.buttonStyle(.wj(.secondary, height: 38, fullWidth: false))
                    }
                    HStack(spacing: 10) {
                        StatusBadge(text: s.t("crowd.capacity", "\(pavilion.capacity ?? 0)"), icon: "person.3", tone: .primary)
                        StatusBadge(text: s.t("crowd.avgVisit", "\(pavilion.avgVisitMinutes ?? 0)"), icon: "clock", tone: .primary)
                        if let loc = pavilion.location {
                            StatusBadge(text: "(\(Int(loc.x)), \(Int(loc.y)))", icon: "mappin", tone: .neutral)
                        }
                    }
                    if let d = pavilion.description { Text(d).font(WJFont.subhead).foregroundStyle(Theme.textPrimary.opacity(0.9)) }

                    Text(s.t("access.title")).font(WJFont.title3).foregroundStyle(Theme.textPrimary).padding(.top, 6)
                    ForEach(AccessNeed.all, id: \.self) { need in
                        let row = details?.accessibility?.first { $0.needType == need }
                        Button { editNeed = need } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                if let row {
                                    AccessRowView(row: row)
                                } else {
                                    HStack {
                                        Text(s.label(need)).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        AccessBadge(status: pavilion.accessStatus(need))
                                    }
                                }
                                Text(s.t("admin.tapToEdit")).font(WJFont.caption).foregroundStyle(Theme.primaryText)
                            }
                            .card(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .screenBackground()
        .wjTopBar(s.t("admin.pavilion"))
        .sheet(isPresented: $editInfo) { PavilionForm(pavilion: expo.pavilion(pavilionId)) }
        .sheet(item: Binding(get: { editNeed.map { NeedItem(id: $0) } }, set: { editNeed = $0?.id })) { item in
            AccessibilityForm(pavilionId: pavilionId, need: item.id, current: details?.accessibility?.first { $0.needType == item.id }) {
                Task { await load() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        details = try? await API.pavilionDetails(pavilionId)
    }
}

struct NeedItem: Identifiable { let id: String }

struct PavilionForm: View {
    let pavilion: Pavilion?
    @Environment(AppSettings.self) private var s
    @Environment(ExpoStore.self) private var expo
    @State private var name = ""
    @State private var country = ""
    @State private var description = ""
    @State private var imageUrl = ""
    @State private var capacity = ""
    @State private var avgVisit = ""
    @State private var zoneId: Int?
    @State private var locationId: Int?

    var body: some View {
        AdminFormSheet(title: pavilion == nil ? s.t("admin.addPavilion") : s.t("admin.editPavilion"), save: save) {
            WJTextField(label: s.t("admin.name"), text: $name, forceLTR: true)
            WJTextField(label: s.t("admin.country"), text: $country, forceLTR: true)
            WJTextField(label: s.t("admin.description"), text: $description, forceLTR: true)
            WJTextField(label: s.t("admin.imageUrl"), text: $imageUrl, keyboard: .URL, forceLTR: true)
            HStack(spacing: 10) {
                WJTextField(label: s.t("admin.capacity"), text: $capacity, keyboard: .numberPad, forceLTR: true)
                WJTextField(label: s.t("admin.avgVisit"), text: $avgVisit, keyboard: .numberPad, forceLTR: true)
            }
            if pavilion == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.t("admin.zone")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(expo.zones) { zone in
                            WJChip(title: s.zoneTitle(zone.name), selected: zoneId == zone.id, compact: true) { zoneId = zone.id }
                        }
                    }
                }
                LocationPicker(label: s.t("admin.location"), selection: $locationId)
            }
        }
        .onAppear {
            guard let pavilion else { return }
            name = pavilion.name
            country = pavilion.country ?? ""
            description = pavilion.description ?? ""
            imageUrl = pavilion.imageUrl ?? ""
            capacity = pavilion.capacity.map { "\($0)" } ?? ""
            avgVisit = pavilion.avgVisitMinutes.map { "\($0)" } ?? ""
        }
    }

    private func save() async throws {
        let body = PavilionBody(name: name, country: country, description: description, imageUrl: imageUrl,
                                capacity: Int(capacity), avgVisitMinutes: Int(avgVisit))
        if let pavilion {
            try await API.updatePavilion(pavilion.id, body)
        } else {
            guard let zoneId, let locationId else { throw APIError(status: 0, message: s.t("admin.zoneAndLocation")) }
            try await API.addPavilion(zoneId: zoneId, locationId: locationId, body)
        }
    }
}

struct AccessibilityForm: View {
    let pavilionId: Int
    let need: String
    let current: PavilionAccessibility?
    var onSaved: () -> Void
    @Environment(AppSettings.self) private var s
    @State private var status = "ACCESSIBLE"
    @State private var note = ""
    @State private var noteAr = ""

    var body: some View {
        AdminFormSheet(title: s.label(need), save: save) {
            Text(s.t("admin.officialStatus")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach(["ACCESSIBLE", "PARTIAL", "NOT_ACCESSIBLE"], id: \.self) { value in
                    WJChip(title: AccessStatus.title(value, s), selected: status == value, showsToggleIcon: status == value, compact: true) { status = value }
                }
            }
            WJTextField(label: s.t("admin.noteEn"), text: $note, forceLTR: true)
            WJTextField(label: s.t("admin.noteAr"), text: $noteAr)
            if let current, current.votes > 0 {
                InfoNote(text: s.t("admin.visitorVotes", "\(current.suitableCount ?? 0)", "\(current.partialCount ?? 0)", "\(current.notSuitableCount ?? 0)"), icon: "person.2")
            }
        }
        .onAppear {
            status = current?.status == "UNKNOWN" ? "ACCESSIBLE" : (current?.status ?? "ACCESSIBLE")
            note = current?.note ?? ""
            noteAr = current?.noteAr ?? ""
        }
    }

    private func save() async throws {
        try await API.updatePavilionAccessibility(pavilionId, need, AccessibilityUpdateBody(status: status, note: note.isEmpty ? nil : note, noteAr: noteAr.isEmpty ? nil : noteAr))
        onSaved()
    }
}

// ===== zones =====
struct AdminZonesView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var editing: Zone?
    @State private var adding = false

    var body: some View {
        AdminList(title: s.t("admin.entity.zones"), items: expo.zones, searchText: { $0.name },
                  onAdd: { adding = true },
                  onDelete: { z in do { try await API.deleteZone(z.id); await expo.load(force: true) } catch { app.showError(error, s) } }) { zone in
            Button { editing = zone } label: {
                AdminRow {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.zoneTitle(zone.name)).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text(s.t("plan.pavilionsCount", "\(zone.pavilions?.count ?? 0)")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $editing) { ZoneForm(zone: $0) }
        .sheet(isPresented: $adding) { ZoneForm(zone: nil) }
    }
}

struct ZoneForm: View {
    let zone: Zone?
    @Environment(AppSettings.self) private var s
    @State private var name = ""
    @State private var description = ""
    @State private var locationId: Int?

    var body: some View {
        AdminFormSheet(title: zone == nil ? s.t("admin.addZone") : s.t("admin.editZone"), save: save) {
            WJTextField(label: s.t("admin.name"), text: $name, forceLTR: true)
            WJTextField(label: s.t("admin.description"), text: $description, forceLTR: true)
            if zone == nil { LocationPicker(label: s.t("admin.location"), selection: $locationId) }
        }
        .onAppear { name = zone?.name ?? ""; description = zone?.description ?? "" }
    }

    private func save() async throws {
        let body = ZoneBody(name: name, description: description)
        if let zone { try await API.updateZone(zone.id, body) } else {
            guard let locationId else { throw APIError(status: 0, message: s.t("admin.chooseLocation")) }
            try await API.addZone(locationId: locationId, body)
        }
    }
}

// ===== entrances =====
struct AdminEntrancesView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var editing: Entrance?
    @State private var adding = false

    var body: some View {
        AdminList(title: s.t("admin.entity.entrances"), items: expo.entrances, searchText: { $0.name },
                  onAdd: { adding = true },
                  onDelete: { e in do { try await API.deleteEntrance(e.id); await expo.load(force: true) } catch { app.showError(error, s) } }) { gate in
            Button { editing = gate } label: {
                AdminRow {
                    Label(s.entranceName(gate.name), systemImage: "door.left.hand.open").font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $editing) { EntranceForm(entrance: $0) }
        .sheet(isPresented: $adding) { EntranceForm(entrance: nil) }
    }
}

struct EntranceForm: View {
    let entrance: Entrance?
    @Environment(AppSettings.self) private var s
    @State private var name = ""
    @State private var locationId: Int?

    var body: some View {
        AdminFormSheet(title: entrance == nil ? s.t("admin.addEntrance") : s.t("admin.editEntrance"), save: save) {
            WJTextField(label: s.t("admin.name"), text: $name, forceLTR: true)
            if entrance == nil { LocationPicker(label: s.t("admin.location"), selection: $locationId) }
        }
        .onAppear { name = entrance?.name ?? "" }
    }

    private func save() async throws {
        let body = EntranceBody(name: name)
        if let entrance { try await API.updateEntrance(entrance.id, body) } else {
            guard let locationId else { throw APIError(status: 0, message: s.t("admin.chooseLocation")) }
            try await API.addEntrance(locationId: locationId, body)
        }
    }
}

// ===== locations =====
struct AdminLocationsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var editing: LocationDTO?
    @State private var adding = false

    var body: some View {
        AdminList(title: s.t("admin.entity.locations"), items: expo.locations, searchText: { "\($0.id)" },
                  onAdd: { adding = true },
                  onDelete: { l in do { try await API.deleteLocation(l.id); await expo.load(force: true) } catch { app.showError(error, s) } }) { loc in
            Button { editing = loc } label: {
                AdminRow {
                    HStack(spacing: 10) {
                        Text("#\(loc.id)").font(WJFont.caption.monospacedDigit()).foregroundStyle(Theme.textTertiary)
                        Text("x \(Int(loc.x)) · y \(Int(loc.y))").font(WJFont.subhead.monospacedDigit()).foregroundStyle(Theme.textPrimary)
                        if let owner = owner(loc.id) {
                            Text(owner).font(WJFont.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $editing) { LocationForm(location: $0) }
        .sheet(isPresented: $adding) { LocationForm(location: nil) }
    }

    private func owner(_ id: Int) -> String? {
        if let p = expo.pavilion(atLocation: id) { return s.pavilionName(p.name) }
        if let z = expo.zones.first(where: { $0.location?.id == id }) { return s.zoneTitle(z.name) }
        if let g = expo.entrances.first(where: { $0.location?.id == id }) { return s.entranceName(g.name) }
        return nil
    }
}

struct LocationForm: View {
    let location: LocationDTO?
    @Environment(AppSettings.self) private var s
    @State private var x = ""
    @State private var y = ""

    var body: some View {
        AdminFormSheet(title: location == nil ? s.t("admin.addLocation") : s.t("admin.editLocation"), save: save) {
            HStack(spacing: 10) {
                WJTextField(label: "X (0–1000)", text: $x, keyboard: .decimalPad, forceLTR: true)
                WJTextField(label: "Y (0–1000)", text: $y, keyboard: .decimalPad, forceLTR: true)
            }
        }
        .onAppear { if let location { x = "\(Int(location.x))"; y = "\(Int(location.y))" } }
    }

    private func save() async throws {
        guard let xv = Double(x), let yv = Double(y) else { throw APIError(status: 0, message: s.t("admin.coordinates")) }
        if let location { try await API.updateLocation(location.id, LocationBody(x: xv, y: yv)) } else { try await API.addLocation(LocationBody(x: xv, y: yv)) }
    }
}

// ===== paths (step free and shaded) =====
struct AdminPathsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var editing: PathDTO?
    @State private var adding = false
    @State private var generating = false

    var body: some View {
        AdminList(title: s.t("admin.entity.paths"), items: expo.paths, searchText: { "\($0.fromLocation?.id ?? 0) \($0.toLocation?.id ?? 0)" },
                  onAdd: { adding = true },
                  onDelete: { p in do { try await API.deletePath(p.id); await expo.load(force: true) } catch { app.showError(error, s) } }) { path in
            Button { editing = path } label: {
                AdminRow {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("#\(path.fromLocation?.id ?? 0) → #\(path.toLocation?.id ?? 0)")
                            .font(WJFont.subhead.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                        HStack(spacing: 6) {
                            Text(s.t("map.meters", "\(Walk.meters(units: path.distance ?? 0))")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                            StatusBadge(text: path.stepFree == false ? s.t("admin.stairs") : s.t("admin.stepFree"),
                                        icon: path.stepFree == false ? "stairs" : "figure.roll", tone: path.stepFree == false ? .warning : .success, compact: true)
                            if path.shaded == true { StatusBadge(text: s.t("admin.shaded"), icon: "sun.haze", tone: .primary, compact: true) }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    generating = true
                    defer { generating = false }
                    do {
                        let message = try await API.generatePaths()
                        await expo.load(force: true)
                        app.show(message ?? s.t("common.done"))
                    } catch { app.showError(error, s) }
                }
            } label: {
                HStack { if generating { ProgressView().tint(.white) } else { Image(systemName: "wand.and.stars") }; Text(s.t("admin.generatePaths")) }
            }
            .buttonStyle(.wjPrimary)
            .disabled(generating)
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 8)
            .background(Theme.canvas.opacity(0.94))
        }
        .sheet(item: $editing) { PathAccessibilityForm(path: $0) }
        .sheet(isPresented: $adding) { PathForm() }
    }
}

struct PathForm: View {
    @Environment(AppSettings.self) private var s
    @State private var from: Int?
    @State private var to: Int?

    var body: some View {
        AdminFormSheet(title: s.t("admin.addPath"), save: save) {
            LocationPicker(label: s.t("admin.from"), selection: $from, onlyFree: false)
            LocationPicker(label: s.t("admin.to"), selection: $to, onlyFree: false)
            InfoNote(text: s.t("admin.pathDistanceNote"))
        }
    }

    private func save() async throws {
        guard let from, let to else { throw APIError(status: 0, message: s.t("admin.chooseLocation")) }
        try await API.addPath(from: from, to: to)
    }
}

struct PathAccessibilityForm: View {
    let path: PathDTO
    @Environment(AppSettings.self) private var s
    @State private var stepFree = true
    @State private var shaded = false

    var body: some View {
        AdminFormSheet(title: "#\(path.fromLocation?.id ?? 0) → #\(path.toLocation?.id ?? 0)", save: save) {
            Toggle(isOn: $stepFree) { Label(s.t("admin.stepFree"), systemImage: "figure.roll").foregroundStyle(Theme.textPrimary) }
                .tint(Theme.primary).card(padding: 14)
            Toggle(isOn: $shaded) { Label(s.t("admin.shaded"), systemImage: "sun.haze").foregroundStyle(Theme.textPrimary) }
                .tint(Theme.primary).card(padding: 14)
        }
        .onAppear { stepFree = path.stepFree ?? true; shaded = path.shaded ?? false }
    }

    private func save() async throws {
        try await API.updatePathAccessibility(path.id, PathAccessibilityBody(stepFree: stepFree, shaded: shaded))
    }
}

// ===== interests =====
struct AdminInterestsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @State private var editing: Interest?
    @State private var adding = false

    var body: some View {
        AdminList(title: s.t("admin.entity.interests"), items: expo.interests, searchText: { "\($0.name) \($0.nameAr ?? "")" },
                  onAdd: { adding = true },
                  onDelete: { i in do { try await API.deleteInterestItem(i.id); await expo.load(force: true) } catch { app.showError(error, s) } }) { interest in
            Button { editing = interest } label: {
                AdminRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(interest.nameAr ?? interest.name).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        Text(interest.name).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $editing) { InterestForm(interest: $0) }
        .sheet(isPresented: $adding) { InterestForm(interest: nil) }
    }
}

struct InterestForm: View {
    let interest: Interest?
    @Environment(AppSettings.self) private var s
    @State private var name = ""
    @State private var nameAr = ""

    var body: some View {
        AdminFormSheet(title: interest == nil ? s.t("admin.addInterest") : s.t("admin.editInterest"), save: save) {
            WJTextField(label: s.t("admin.nameEn"), text: $name, forceLTR: true)
            WJTextField(label: s.t("admin.nameAr"), text: $nameAr)
        }
        .onAppear { name = interest?.name ?? ""; nameAr = interest?.nameAr ?? "" }
    }

    private func save() async throws {
        let body = InterestBody(name: name, nameAr: nameAr)
        if let interest { try await API.updateInterestItem(interest.id, body) } else { try await API.addInterestItem(body) }
    }
}
