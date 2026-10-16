import SwiftUI

// ACC-01: account hub
struct AccountView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @State private var editing: PersonalField?

    enum PersonalField: String, Identifiable { case age, gender, nationality, language; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.top, 12)

                group(s.t("account.personal")) {
                    row("person", s.t("register.age"), value: visitor.info?.age.map { "\($0)" }) { editing = .age }
                    row("person.2", s.t("register.gender"), value: s.label(visitor.info?.gender)) { editing = .gender }
                    row("globe", s.t("register.nationality"), value: visitor.info?.nationality) { editing = .nationality }
                    row("character.bubble", s.t("account.preferredLanguage"), value: visitor.info?.preferredLanguage == "EN" ? "English" : "العربية") { editing = .language }
                    row("heart", s.t("interests.title"), value: s.t("account.interestsCount", "\(visitor.info?.interests?.count ?? 0)"), last: true) { router.push(.interests) }
                }

                group(s.t("account.account")) {
                    row("envelope", s.t("register.email"), value: visitor.info?.email, ltr: true) { router.push(.accountDetails) }
                    row("phone", s.t("register.phone"), value: visitor.info?.phone, ltr: true) { router.push(.accountDetails) }
                    row("lock", s.t("register.password"), value: "••••••••", last: true) { router.push(.accountDetails) }
                }

                InfoNote(text: s.t("account.passwordNote"), icon: "lock")

                group(s.t("account.app")) {
                    row(s.appearance.icon, s.t("settings.title"), value: s.t("settings.appearance.\(s.appearance.rawValue)")) { router.push(.settings) }
                    row("bell.badge", s.t("alerts.title"), value: visitor.newAlerts.isEmpty ? nil : "\(visitor.newAlerts.count)", last: true) { router.push(.crowdAlerts) }
                }

                VStack(spacing: 0) {
                    row("rectangle.portrait.and.arrow.right", s.t("account.logout"), value: nil) { confirmLogout() }
                    row("trash", s.t("account.delete"), value: nil, destructive: true, last: true) { router.push(.deleteAccount) }
                }
                .card(padding: 0)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await visitor.refreshInfo() }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .wjTabBar()
        .sheet(item: $editing) { field in PersonalFieldSheet(field: field) }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(visitor.info?.initial ?? "؟")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(LinearGradient(colors: [Palette.blue400, Palette.blue600], startPoint: .top, endPoint: .bottom), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(visitor.info?.fullName ?? app.username).font(WJFont.title2).foregroundStyle(Theme.textPrimary)
                Text("@\(visitor.info?.username ?? app.username) · \(s.t("passport.number")) \(visitor.info?.passportNumber ?? "—")")
                    .font(WJFont.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(WJFont.captionBold)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 2)
            content()
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func row(_ icon: String, _ title: String, value: String?, ltr: Bool = false, destructive: Bool = false, last: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 22)
                        .foregroundStyle(destructive ? Theme.danger : Theme.textSecondary)
                    Text(title)
                        .font(WJFont.callout.weight(.semibold))
                        .foregroundStyle(destructive ? Theme.danger : Theme.textPrimary)
                    Spacer()
                    if let value {
                        Text(value)
                            .font(WJFont.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .environment(\.layoutDirection, ltr ? .leftToRight : s.layoutDirection)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                if !last { Divider().overlay(Theme.divider).padding(.leading, 50) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // OVL-ACC-01
    private func confirmLogout() {
        app.ask(DialogModel(icon: "rectangle.portrait.and.arrow.right", tone: .primary, title: s.t("account.logoutTitle"),
                            message: s.t("account.logoutMessage"), primary: s.t("account.logout"), primaryRole: .destructive,
                            secondary: s.t("common.cancel"), onPrimary: {
            Task { await app.logout(visitorStore: visitor) }
        }))
    }
}

// PUT /visitor/updateVisitor (age, gender, nationality, preferred language) — one field at a time
struct PersonalFieldSheet: View {
    let field: AccountView.PersonalField
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(\.dismiss) private var dismiss
    @State private var age = ""
    @State private var gender = ""
    @State private var nationality = ""
    @State private var language = "AR"
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: title)
            switch field {
            case .age:
                WJTextField(label: s.t("register.age"), text: $age, keyboard: .numberPad, forceLTR: true)
            case .gender:
                HStack(spacing: 10) {
                    WJChip(title: s.label("MALE"), selected: gender == "MALE", showsToggleIcon: gender == "MALE") { gender = "MALE" }
                    WJChip(title: s.label("FEMALE"), selected: gender == "FEMALE", showsToggleIcon: gender == "FEMALE") { gender = "FEMALE" }
                }
            case .nationality:
                WJTextField(label: s.t("register.nationality"), text: $nationality)
            case .language:
                Text(s.t("account.languageHint")).font(WJFont.footnote).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) {
                    WJChip(title: "العربية", selected: language == "AR", showsToggleIcon: language == "AR") { language = "AR" }
                    WJChip(title: "English", selected: language == "EN", showsToggleIcon: language == "EN") { language = "EN" }
                }
            }
            if let error { InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .danger) }
            Spacer(minLength: 0)
            Button {
                Task { await save() }
            } label: {
                HStack { if saving { ProgressView().tint(.white) }; Text(s.t("common.save")) }
            }
            .buttonStyle(.wjPrimary)
            .disabled(saving)
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 8)
        .wjSheet([.height(330)])
        .onAppear {
            let info = visitor.info
            age = info?.age.map { "\($0)" } ?? ""
            gender = info?.gender ?? ""
            nationality = info?.nationality ?? ""
            language = info?.preferredLanguage ?? "AR"
        }
    }

    private var title: String {
        switch field {
        case .age: return s.t("register.age")
        case .gender: return s.t("register.gender")
        case .nationality: return s.t("register.nationality")
        case .language: return s.t("account.preferredLanguage")
        }
    }

    private func save() async {
        guard let ageValue = Int(age), (1...120).contains(ageValue) else { error = s.t("validation.age"); return }
        guard !nationality.trimmingCharacters(in: .whitespaces).isEmpty else { error = s.t("validation.nationality"); return }
        guard !gender.isEmpty else { error = s.t("validation.gender"); return }
        saving = true
        defer { saving = false }
        do {
            try await API.updateVisitor(UpdateVisitorBody(age: ageValue, gender: gender, preferredLanguage: language, nationality: nationality))
            await visitor.refreshInfo()
            if field == .language { s.language = language == "EN" ? .en : .ar }
            app.show(s.t("account.saved"))
            dismiss()
        } catch {
            self.error = AppState.message(error, s)
        }
    }
}

// ACC-02: interests (at least 3), one change at a time on the backend
struct InterestsEditView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Int> = []
    @State private var saving = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(s.t("interests.editTitle")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
                    Text(s.t("interests.editSubtitle")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)
                    FlowLayout(spacing: 8, lineSpacing: 10) {
                        ForEach(expo.interests) { interest in
                            WJChip(title: s.interestName(interest), selected: selected.contains(interest.id)) {
                                if selected.contains(interest.id) { selected.remove(interest.id) } else { selected.insert(interest.id) }
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 24)
                .maxContentWidth()
            }
            VStack(spacing: 6) {
                Text(selected.count >= 3 ? s.t("interests.count", "\(selected.count)") : s.t("interests.minimum", "\(selected.count)"))
                    .font(WJFont.captionBold)
                    .foregroundStyle(selected.count >= 3 ? Theme.accent : Theme.danger)
                Button {
                    Task { await save() }
                } label: {
                    HStack { if saving { ProgressView().tint(.white) }; Text(s.t("common.save")) }
                }
                .buttonStyle(.wjPrimary)
                .disabled(selected.count < 3 || saving || selected == current)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .screenBackground()
        .wjTopBar(s.t("interests.title"))
        .onAppear { selected = current }
        .task { await expo.load() }
    }

    private var current: Set<Int> { Set((visitor.info?.interests ?? []).map(\.id)) }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            // add first so the visitor never drops under 3 interests
            for id in selected.subtracting(current) { try await API.addInterest(id) }
            for id in current.subtracting(selected) { try await API.removeInterest(id) }
            await visitor.refreshInfo()
            app.show(s.t("interests.saved"))
            dismiss()
        } catch {
            app.showError(error, s)
            await visitor.refreshInfo()
            selected = current
        }
    }
}

// ACC-03: name, username, email, phone and password (PUT /user/updateUser needs the password every time)
struct AccountDetailsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var newPassword = ""
    @State private var currentPassword = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WJTextField(label: s.t("register.fullName"), text: $fullName)
                    WJTextField(label: s.t("register.username"), text: $username, forceLTR: true)
                    WJTextField(label: s.t("register.email"), text: $email, keyboard: .emailAddress, forceLTR: true)
                    WJTextField(label: s.t("register.phone"), text: $phone, keyboard: .phonePad, forceLTR: true)
                    WJTextField(label: s.t("account.newPassword"), text: $newPassword, placeholder: s.t("account.newPasswordHint"), secure: true, contentType: .newPassword, forceLTR: true)
                    Divider().overlay(Theme.divider)
                    WJTextField(label: s.t("account.currentPassword"), text: $currentPassword, secure: true, contentType: .password, forceLTR: true)
                    InfoNote(text: s.t("account.currentPasswordNote"), icon: "lock")
                    if let error { InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .danger) }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .maxContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            Button {
                Task { await save() }
            } label: {
                HStack { if saving { ProgressView().tint(.white) }; Text(s.t("edit.save")) }
            }
            .buttonStyle(.wjPrimary)
            .disabled(saving || currentPassword.isEmpty)
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .screenBackground()
        .wjTopBar(s.t("account.detailsTitle"))
        .onAppear {
            let info = visitor.info
            fullName = info?.fullName ?? ""
            username = info?.username ?? app.username
            email = info?.email ?? ""
            phone = info?.phone ?? ""
        }
    }

    private func save() async {
        error = nil
        guard currentPassword == app.savedPassword else { error = s.t("account.wrongCurrent"); return }
        if !newPassword.isEmpty && newPassword.count < 8 { error = s.t("validation.password"); return }
        if !(4...20).contains(username.count) { error = s.t("validation.username"); return }
        if phone.range(of: #"^\+[1-9]\d{7,14}$"#, options: .regularExpression) == nil { error = s.t("validation.phone"); return }
        saving = true
        defer { saving = false }
        let password = newPassword.isEmpty ? currentPassword : newPassword
        do {
            try await API.updateUser(UpdateUserBody(fullName: fullName, username: username, password: password, email: email, phone: phone))
            app.updateSavedPassword(username: username, password: password)
            await visitor.refreshInfo()
            app.show(s.t("account.saved"))
            dismiss()
        } catch {
            self.error = AppState.message(error, s)
        }
    }
}

// ACC-04: full screen destructive confirmation (DELETE /user/deleteUser)
struct DeleteAccountView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.danger)
                    Text(s.t("delete.title")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
                    Text(s.t("delete.subtitle")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 10) {
                        item(s.t("delete.passport"))
                        item(s.t("delete.visits"))
                        item(s.t("delete.reviews", "\(visitor.myReviews.count)"))
                        item(s.t("delete.plans"))
                    }
                    WJTextField(label: s.t("delete.passwordLabel"), text: $password, secure: true, contentType: .password, forceLTR: true)
                    if let error { InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .danger) }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 24)
                .maxContentWidth()
            }
            VStack(spacing: 6) {
                Button {
                    Task { await delete() }
                } label: {
                    HStack { if deleting { ProgressView().tint(.white) } else { Image(systemName: "trash") }; Text(s.t("delete.confirm")) }
                }
                .buttonStyle(.wjDestructive)
                .disabled(password.isEmpty || deleting)
                Button(s.t("delete.back")) { dismiss() }
                    .buttonStyle(.wjTertiary)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
        }
        .screenBackground(.none)
        .wjTopBar("")
    }

    private func item(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.danger)
            Text(text).font(WJFont.subhead.weight(.semibold)).foregroundStyle(Theme.textPrimary)
        }
    }

    private func delete() async {
        // password re-entry is a client side guard
        guard password == app.savedPassword else { error = s.t("account.wrongCurrent"); return }
        deleting = true
        defer { deleting = false }
        do {
            try await API.deleteMyUser()
            app.clearSession(visitorStore: visitor)
        } catch {
            self.error = AppState.message(error, s)
        }
    }
}

// app settings: appearance, app language, map style and server address
struct SettingsView: View {
    @Environment(AppSettings.self) private var s
    @State private var showServer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(s.t("settings.appearance")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 10) {
                        ForEach(AppAppearance.allCases) { option in
                            appearanceCard(option)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(s.t("settings.language")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 10) {
                        ForEach(AppLanguage.allCases) { lang in
                            WJChip(title: lang.displayName, selected: s.language == lang, showsToggleIcon: s.language == lang) { s.language = lang }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(s.t("settings.mapStyle")).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                    MapStyleSwitch()
                }
                Button {
                    showServer = true
                } label: {
                    HStack {
                        Label(s.t("server.title"), systemImage: "server.rack").font(WJFont.callout.weight(.semibold))
                        Spacer()
                        Text(s.serverURL).font(WJFont.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .card(padding: 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .screenBackground()
        .wjTopBar(s.t("settings.title"))
        .sheet(isPresented: $showServer) { ServerAddressSheet() }
    }

    private func appearanceCard(_ option: AppAppearance) -> some View {
        let on = s.appearance == option
        return Button {
            withAnimation { s.appearance = option }
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(option == .light ? Palette.ink50 : (option == .dark ? Palette.ink900 : Palette.ink500))
                    .frame(height: 54)
                    .overlay(
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(Palette.blue500).frame(width: 30, height: 6)
                            Capsule().fill(option == .light ? Palette.ink200 : Palette.ink600).frame(width: 46, height: 6)
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                Label(s.t("settings.appearance.\(option.rawValue)"), systemImage: option.icon)
                    .font(WJFont.caption.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(on ? Theme.primarySoft : Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.primary : Theme.border, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

// WhatsApp crowd alerts: the pavilion in my plan is crowded now and calm soon; accepting moves it in the plan
struct CrowdAlertsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @Environment(Router.self) private var router
    @State private var accepting: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                InfoNote(text: s.t("alerts.explain"), icon: "bell.badge")
                if visitor.alerts.isEmpty {
                    EmptyStateView(icon: "bell.slash", title: s.t("alerts.emptyTitle"), message: s.t("alerts.emptyMessage"))
                }
                ForEach(visitor.alerts.sorted { ($0.sentAt ?? "") > ($1.sentAt ?? "") }) { alert in
                    alertCard(alert)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
            .maxContentWidth()
        }
        .refreshable { await visitor.refreshAlerts() }
        .screenBackground()
        .wjTopBar(s.t("alerts.title"))
        .task { await visitor.refreshAlerts() }
    }

    private func alertCard(_ alert: CrowdAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(s.pavilionName(alert.pavilionName)).font(WJFont.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(DateText.clock12(DateText.clock(alert.sentAt), s)).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: 8) {
                CrowdBadge(minutes: alert.waitNow, level: "CROWDED")
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textTertiary).flipsForRightToLeftLayoutDirection(true)
                CrowdBadge(minutes: alert.waitCalm, level: "CALM")
                Text(s.t("alerts.at", DateText.clock12(alert.calmAt, s))).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
            }
            Text(s.t("alerts.cardMessage", "\(alert.waitNow ?? 0)", DateText.clock12(alert.calmAt, s), "\(alert.waitCalm ?? 0)"))
                .font(WJFont.footnote)
                .foregroundStyle(Theme.textSecondary)
            if alert.accepted == true {
                StatusBadge(text: s.t("alerts.accepted"), icon: "checkmark", tone: .success)
            } else {
                HStack(spacing: 10) {
                    Button {
                        Task { await accept(alert) }
                    } label: {
                        HStack { if accepting == alert.alertId { ProgressView().tint(.white) }; Text(s.t("alerts.accept")) }
                    }
                    .buttonStyle(.wj(.primary, height: 44))
                    .disabled(accepting != nil)
                    if let id = alert.pavilionId {
                        Button(s.t("common.details")) { router.push(.pavilion(id)) }
                            .buttonStyle(.wj(.secondary, height: 44))
                    }
                }
                if alert.delivered == false {
                    Text(s.t("alerts.notDelivered")).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .card(padding: 14)
    }

    private func accept(_ alert: CrowdAlert) async {
        accepting = alert.alertId
        defer { accepting = nil }
        do {
            let updated = try await API.acceptCrowdAlert(alert.alertId)
            visitor.replace(updated)
            await visitor.refreshAlerts()
            app.show(s.t("alerts.moved", s.pavilionName(alert.pavilionName)))
        } catch {
            app.showError(error, s)
        }
    }
}
