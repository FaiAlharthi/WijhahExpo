import SwiftUI

enum AuthStep: Hashable {
    case signUp, signUpProfile, interests, login
}

// AUTH-SU / AUTH-LI: welcome, two step sign up, interests and log in
struct AuthFlowView: View {
    static var startAt: AuthStep?
    @State private var path: [AuthStep] = []
    @State private var form = RegisterRequest()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(path: $path)
                .navigationDestination(for: AuthStep.self) { step in
                    switch step {
                    case .signUp: SignUpAccountView(form: $form, path: $path)
                    case .signUpProfile: SignUpProfileView(form: $form, path: $path)
                    case .interests: ChooseInterestsView(username: form.username, password: form.password)
                    case .login: LoginView(path: $path)
                    }
                }
        }
        .onAppear {
            if let start = Self.startAt {
                path = [start]
                Self.startAt = nil
            }
        }
    }
}

// AUTH-SU-01
struct WelcomeView: View {
    @Binding var path: [AuthStep]
    @Environment(AppState.self) private var app
    @Environment(AppSettings.self) private var s
    @State private var showServer = false
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Menu {
                    Button { s.language = s.isArabic ? .en : .ar } label: {
                        Label(s.isArabic ? "English" : "العربية", systemImage: "globe")
                    }
                    Button { showServer = true } label: {
                        Label(s.t("server.title"), systemImage: "server.rack")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: Metrics.touch, height: Metrics.touch)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 18) {
                WijhaMark(size: 76)
                    .scaleEffect(appear ? 1 : 0.8)
                Text(s.t("app.name"))
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text(s.t("welcome.message"))
                    .font(WJFont.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)

            Spacer()

            VStack(spacing: 12) {
                Text(s.t("welcome.guestHint"))
                    .font(WJFont.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
                Button(s.t("auth.createAccount")) { path.append(.signUp) }
                    .buttonStyle(.wjPrimary)
                Button(s.t("auth.login")) { path.append(.login) }
                    .buttonStyle(.wjSecondary)
                Button(s.t("auth.guest")) { app.guest = true }
                    .buttonStyle(.wjTertiary)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 12)
            .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1).offset(y: -14) }
        }
        .maxContentWidth()
        .screenBackground(.lime)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showServer) { ServerAddressSheet() }
        .onAppear { withAnimation(.spring(duration: 0.7)) { appear = true } }
    }
}

// AUTH-SU-02: step 1, account details
struct SignUpAccountView: View {
    @Binding var form: RegisterRequest
    @Binding var path: [AuthStep]
    @Environment(AppSettings.self) private var s
    @State private var tried = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    EyebrowLabel(text: s.t("signup.step1"))
                    Text(s.t("signup.title")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)

                    field(s.t("register.fullName"), $form.fullName, hint: s.t("signup.fullNameHint"), error: errors["fullName"], type: .name)
                    field(s.t("register.username"), $form.username, hint: s.t("signup.usernameHint"), error: errors["username"], ltr: true, type: .username)
                    field(s.t("register.email"), $form.email, hint: nil, error: errors["email"], ltr: true, keyboard: .emailAddress, type: .emailAddress)
                    field(s.t("register.phone"), $form.phone, hint: s.t("signup.phoneHint"), error: errors["phone"], ltr: true, keyboard: .phonePad, type: .telephoneNumber)
                    field(s.t("register.password"), $form.password, hint: s.t("signup.passwordHint"), error: errors["password"], ltr: true, secure: true, type: .newPassword)
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(s.t("common.next")) {
                tried = true
                if errors.isEmpty { path.append(.signUpProfile) }
            }
            .buttonStyle(.wjPrimary)
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .maxContentWidth()
        .screenBackground()
        .wjTopBar("")
    }

    private var errors: [String: String] {
        guard tried else { return [:] }
        var e: [String: String] = [:]
        let name = form.fullName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty || name.count > 50 { e["fullName"] = s.t("validation.fullName") }
        if !(4...20).contains(form.username.count) { e["username"] = s.t("validation.username") }
        if form.email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) == nil { e["email"] = s.t("validation.email") }
        if form.phone.range(of: #"^\+[1-9]\d{7,14}$"#, options: .regularExpression) == nil { e["phone"] = s.t("validation.phone") }
        if form.password.count < 8 { e["password"] = s.t("validation.password") }
        return e
    }

    private func field(_ label: String, _ text: Binding<String>, hint: String?, error: String?, ltr: Bool = false, secure: Bool = false, keyboard: UIKeyboardType = .default, type: UITextContentType? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WJTextField(label: label, text: text, secure: secure, keyboard: keyboard, contentType: type, error: error, forceLTR: ltr)
            if let hint, error == nil {
                Text(hint).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// AUTH-SU-03: step 2, profile used to suggest the plan
struct SignUpProfileView: View {
    @Binding var form: RegisterRequest
    @Binding var path: [AuthStep]
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @State private var ageText = ""
    @State private var tried = false
    @State private var saving = false
    @State private var serverError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EyebrowLabel(text: s.t("signup.step2"))
                    Text(s.t("signup.profileTitle")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: 6) {
                        WJTextField(label: s.t("register.age"), text: $ageText, keyboard: .numberPad, error: ageError, forceLTR: true)
                        if ageError == nil {
                            Text(s.t("signup.ageHint")).font(WJFont.caption).foregroundStyle(Theme.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(s.t("register.gender")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 10) {
                            genderChip("MALE")
                            genderChip("FEMALE")
                        }
                        if tried && form.gender.isEmpty {
                            Text(s.t("validation.gender")).font(WJFont.caption).foregroundStyle(Theme.danger)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(s.t("signup.languageTitle")).font(WJFont.label).foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 10) {
                            languageChip("AR", "العربية")
                            languageChip("EN", "English")
                        }
                    }

                    WJTextField(label: s.t("register.nationality"), text: $form.nationality, placeholder: s.t("signup.nationalityPlaceholder"),
                                error: tried && form.nationality.trimmingCharacters(in: .whitespaces).isEmpty ? s.t("validation.nationality") : nil)

                    if let serverError {
                        InfoNote(text: serverError, icon: "exclamationmark.triangle.fill", tone: .danger)
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                Text(s.t("signup.consent")).font(WJFont.caption).foregroundStyle(Theme.textTertiary).multilineTextAlignment(.center)
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if saving { ProgressView().tint(.white) }
                        Text(saving ? s.t("signup.creating") : s.t("auth.createAccount"))
                    }
                }
                .buttonStyle(.wjPrimary)
                .disabled(saving)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .maxContentWidth()
        .screenBackground()
        .wjTopBar("")
        .onAppear {
            if ageText.isEmpty && form.age > 0 { ageText = "\(form.age)" }
            if form.preferredLanguage.isEmpty { form.preferredLanguage = s.language.apiValue }
        }
    }

    private var ageError: String? {
        guard tried else { return nil }
        guard let age = Int(ageText), (1...120).contains(age) else { return s.t("validation.age") }
        return nil
    }

    private func genderChip(_ value: String) -> some View {
        WJChip(title: s.label(value), selected: form.gender == value, showsToggleIcon: form.gender == value) { form.gender = value }
    }

    private func languageChip(_ value: String, _ title: String) -> some View {
        WJChip(title: title, selected: form.preferredLanguage == value, showsToggleIcon: form.preferredLanguage == value) {
            form.preferredLanguage = value
        }
    }

    private func submit() async {
        tried = true
        serverError = nil
        guard ageError == nil, !form.gender.isEmpty, !form.nationality.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        form.age = Int(ageText) ?? form.age
        saving = true
        defer { saving = false }
        do {
            try await API.register(form)
            // the app language follows the choice
            s.language = form.preferredLanguage == "EN" ? .en : .ar
            path.append(.interests)
        } catch {
            serverError = AppState.message(error, s)
        }
    }
}

// AUTH-SU-04: pick at least 3 interests, then go home
struct ChooseInterestsView: View {
    let username: String
    let password: String
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(ExpoStore.self) private var expo
    @Environment(VisitorStore.self) private var visitor
    @State private var selected: Set<Int> = []
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(s.t("interests.title")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
                    Text(s.t("interests.subtitle")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)
                    if expo.interests.isEmpty {
                        SkeletonList(count: 3, height: 40)
                    }
                    FlowLayout(spacing: 8, lineSpacing: 10) {
                        ForEach(expo.interests) { interest in
                            WJChip(title: s.interestName(interest), selected: selected.contains(interest.id)) {
                                if selected.contains(interest.id) { selected.remove(interest.id) } else { selected.insert(interest.id) }
                                Haptics.tap()
                            }
                        }
                    }
                    if let error {
                        InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .danger)
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 8)
            }

            VStack(spacing: 8) {
                Text(selected.count >= 3 ? s.t("interests.count", "\(selected.count)") : s.t("interests.minimum", "\(selected.count)"))
                    .font(WJFont.captionBold)
                    .foregroundStyle(selected.count >= 3 ? Theme.accent : Theme.textSecondary)
                Button {
                    Task { await finish() }
                } label: {
                    HStack(spacing: 8) {
                        if saving { ProgressView().tint(.white) }
                        Text(s.t("common.continue"))
                    }
                }
                .buttonStyle(.wjPrimary)
                .disabled(selected.count < 3 || saving)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .maxContentWidth()
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await expo.load() }
    }

    private func finish() async {
        saving = true
        defer { saving = false }
        error = nil
        APIClient.shared.setCredentials(username: username, password: password)

        // the account was just created — confirm it can authenticate before using it,
        // with one short retry, so a brief server-side commit gap never dead-ends signup
        var ok = false
        var authError: Error?
        let delays: [UInt64] = [0, 700, 1400]   // retry a few times, escalating, to bridge the commit gap
        for delay in delays {
            if delay > 0 { try? await Task.sleep(for: .milliseconds(Int(delay))) }
            do {
                _ = try await API.myInfo()
                ok = true
                break
            } catch let e as APIError where e.status == 403 {
                ok = true          // 403 = admin account, still authenticated
                break
            } catch let e as APIError where e.status == 401 {
                authError = e      // not committed yet — wait and retry
            } catch {
                authError = error
                break              // a real error (offline, etc.) — stop retrying
            }
        }
        guard ok else {
            self.error = authError.map { AppState.message($0, s) } ?? s.t("error.title")
            return
        }

        // save the chosen interests (best-effort — never block entry on them)
        for id in selected {
            try? await API.addInterest(id)
        }

        do {
            try await app.login(username: username, password: password, visitorStore: visitor)
        } catch {
            self.error = AppState.message(error, s)
        }
    }
}

// AUTH-LI-01 / 02
struct LoginView: View {
    @Binding var path: [AuthStep]
    @Environment(AppSettings.self) private var s
    @Environment(AppState.self) private var app
    @Environment(VisitorStore.self) private var visitor
    @State private var username = ""
    @State private var password = ""
    @State private var tried = false
    @State private var loading = false
    @State private var error: String?
    @FocusState private var focus: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(s.t("auth.login")).font(WJFont.title1).foregroundStyle(Theme.textPrimary)
                    Text(s.t("login.subtitle")).font(WJFont.subhead).foregroundStyle(Theme.textSecondary)

                    WJTextField(label: s.t("register.username"), text: $username, contentType: .username,
                                error: tried && username.isEmpty ? s.t("validation.required") : nil, forceLTR: true)
                    WJTextField(label: s.t("register.password"), text: $password, secure: true, contentType: .password,
                                error: tried && password.isEmpty ? s.t("validation.required") : nil, forceLTR: true,
                                submitLabel: .go, onSubmit: { Task { await submit() } })

                    if let error {
                        InfoNote(text: error, icon: "exclamationmark.triangle.fill", tone: .danger)
                            .transition(.opacity)
                    }
                    InfoNote(text: s.t("login.noReset"))
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 6) {
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if loading { ProgressView().tint(.white) }
                        Text(loading ? s.t("login.signingIn") : s.t("login.button"))
                    }
                }
                .buttonStyle(.wjPrimary)
                .disabled(loading)
                Button(s.t("login.noAccount")) {
                    path = [.signUp]
                }
                .buttonStyle(.wjTertiary)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.vertical, 12)
            .background(Theme.canvas.opacity(0.94))
        }
        .maxContentWidth()
        .screenBackground()
        .wjTopBar("")
        .animation(.easeOut(duration: 0.2), value: error)
    }

    private func submit() async {
        tried = true
        error = nil
        guard !username.isEmpty, !password.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            try await app.login(username: username.trimmingCharacters(in: .whitespaces), password: password, visitorStore: visitor)
        } catch let e as APIError where e.status == 401 {
            error = s.t("error.wrongCredentials")
            Haptics.error()
        } catch {
            self.error = AppState.message(error, s)
            Haptics.error()
        }
    }
}

// the backend address (simulator: localhost, real iPhone: the Mac IP)
struct ServerAddressSheet: View {
    @Environment(AppSettings.self) private var s
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var status: String?
    @State private var checking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: s.t("server.title"))
            WJTextField(label: s.t("server.label"), text: $address, placeholder: "http://192.168.1.5:8080", keyboard: .URL, forceLTR: true)
            Text(s.t("server.hint")).font(WJFont.caption).foregroundStyle(Theme.textSecondary)
            if let status {
                InfoNote(text: status, icon: status == s.t("server.ok") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                         tone: status == s.t("server.ok") ? .success : .danger)
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button {
                    Task { await check() }
                } label: {
                    HStack { if checking { ProgressView() }; Text(s.t("server.test")) }
                }
                .buttonStyle(.wjSecondary)
                Button(s.t("common.save")) {
                    s.serverURL = address
                    dismiss()
                }
                .buttonStyle(.wjPrimary)
            }
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 12)
        .wjSheet([.height(420)])
        .onAppear { address = s.serverURL }
    }

    private func check() async {
        checking = true
        defer { checking = false }
        let old = APIClient.shared.baseURL
        APIClient.shared.baseURL = address
        defer { APIClient.shared.baseURL = old }
        do {
            _ = try await API.zones()
            status = s.t("server.ok")
        } catch {
            status = AppState.message(error, s)
        }
    }
}
