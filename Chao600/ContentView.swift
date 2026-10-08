import SwiftUI

struct ContentView: View {
    @Environment(BlockerModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    StatusCard()
                }

                Section {
                    Toggle(isOn: $model.config.block600) {
                        PrefixLabel(prefix: "600", detail: "Empresas con las que tienes relación: bancos, isapres, retail, cobranzas.")
                    }
                    .tint(.green)
                    Toggle(isOn: $model.config.block809) {
                        PrefixLabel(prefix: "809", detail: "Telemarketing que no pediste.")
                    }
                    .tint(.green)
                } header: {
                    Text("Bloquear")
                }

                Section {
                    Toggle("Incluir números sin +56", isOn: $model.config.includeNationalFormat)
                        .tint(.green)
                } header: {
                    Text("Avanzado")
                } footer: {
                    Text("Actívalo solo si te siguen entrando llamadas 600 u 809. Duplica los números a cargar.")
                }

                Section {
                } footer: {
                    Label("Todo ocurre en tu iPhone. Chao 600 no ve tus llamadas ni tus contactos, y no se conecta a internet.", systemImage: "lock.fill")
                        .font(.footnote)
                }
            }
            .navigationTitle("Chao 600")
        }
    }
}

private struct StatusCard: View {
    @Environment(BlockerModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch model.status {
            case .checking:
                header("shield", .secondary, "Revisando…", "Un momento.")
            case .needsSetup:
                header("exclamationmark.shield.fill", .orange, "Falta un paso",
                       "Toca Abrir Ajustes, activa Chao 600 en Bloqueo e identificación de llamadas y vuelve aquí.")
                Button {
                    Task { await model.openSettings() }
                } label: {
                    Text("Abrir Ajustes").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            case let .loading(done, total):
                header("shield.lefthalf.filled", Color(.accent), "Cargando números…",
                       "\(done.chilean) de \(total.chilean). Deja la app abierta un momento.")
                ProgressView(value: Double(done), total: Double(max(total, 1)))
            case let .active(total) where total == 0:
                header("shield.slash", .secondary, "Sin bloqueo", "Activa 600 u 809 para empezar.")
            case let .active(total):
                header("checkmark.shield.fill", .green, "Protegido", "\(total.chilean) números bloqueados.")
            case let .failed(message):
                header("xmark.shield.fill", .red, "No se pudo cargar", message)
                Button {
                    Task { await model.refresh() }
                } label: {
                    Text("Reintentar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(.vertical, 6)
        .animation(.default, value: model.status)
    }

    private func header(_ symbol: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 36))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.bold())
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PrefixLabel: View {
    let prefix: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Text(prefix)
                .font(.callout.monospacedDigit().bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.accent), in: .rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Números \(prefix)")
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private extension Int64 {
    var chilean: String { formatted(.number.locale(Locale(identifier: "es_CL"))) }
}

#Preview {
    ContentView().environment(BlockerModel())
}
