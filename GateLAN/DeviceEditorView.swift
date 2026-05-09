import SwiftUI

struct DeviceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DeviceStore

    let existing: BarrierDevice?

    @State private var name = ""
    @State private var brandID = "custom"
    @State private var host = ""
    @State private var port = "80"
    @State private var scheme = "http"
    @State private var path = "/"
    @State private var note = ""
    @State private var username = ""
    @State private var password = ""
    @State private var saveCredential = false

    var body: some View {
        NavigationStack {
            Form {
                Section("设备") {
                    TextField("名称", text: $name)
                    Picker("品牌", selection: $brandID) {
                        ForEach(BrandCatalog.brands) { brand in
                            Text(brand.name).tag(brand.id)
                        }
                    }
                    .onChange(of: brandID) { id in
                        applyBrand(BrandCatalog.brand(for: id))
                    }
                    TextField("IP 或主机名", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("协议", selection: $scheme) {
                        Text("HTTP").tag("http")
                        Text("HTTPS").tag("https")
                    }
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    TextField("路径", text: $path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("授权凭据") {
                    Toggle("保存账号到本机钥匙串", isOn: $saveCredential)
                    if saveCredential {
                        TextField("账号", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("密码", text: $password)
                    }
                }

                Section("备注") {
                    TextField("位置、用途或维护说明", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(existing == nil ? "添加设备" : "编辑设备")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(port) != nil
    }

    private func loadExisting() {
        guard let existing else { return }
        name = existing.name
        brandID = existing.brandID
        host = existing.host
        port = "\(existing.port)"
        scheme = existing.scheme
        path = existing.path
        note = existing.note
        if let credential = store.credential(for: existing.id) {
            saveCredential = true
            username = credential.username
            password = credential.password
        }
    }

    private func applyBrand(_ brand: BarrierBrand) {
        guard existing == nil else { return }
        scheme = brand.defaultScheme
        port = "\(brand.defaultPort)"
        path = brand.defaultPath
        if name.isEmpty, brand.id != "custom" {
            name = brand.name
        }
    }

    private func save() {
        let credential = saveCredential ? StoredCredential(username: username, password: password) : nil
        let device = BarrierDevice(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brandID: brandID,
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: Int(port) ?? 80,
            scheme: scheme,
            path: path.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            lastCheckedAt: existing?.lastCheckedAt,
            isOnline: existing?.isOnline
        )
        if existing == nil {
            store.add(device, credential: credential)
        } else {
            store.update(device, credential: credential)
        }
        dismiss()
    }
}
