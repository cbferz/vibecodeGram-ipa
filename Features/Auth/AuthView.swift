import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model: AuthViewModel

    init(api: APIClient) {
        _model = StateObject(wrappedValue: AuthViewModel(api: api, session: SessionStoreProxy.shared))
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.primary)
                Text("vibecodeGram")
                    .font(.largeTitle.weight(.bold))
                Text(model.isRegistering ? "Создайте аккаунт" : "С возвращением")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                TextField("Имя пользователя", text: $model.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .textFieldStyle(.roundedBorder)

                if model.isRegistering {
                    TextField("Отображаемое имя", text: $model.displayName)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                }

                SecureField("Пароль", text: $model.password)
                    .textContentType(model.isRegistering ? .newPassword : .password)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            Button {
                Task { await model.submit() }
            } label: {
                HStack {
                    if model.isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(model.isRegistering ? "Зарегистрироваться" : "Войти")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isSubmitting)

            Button(model.isRegistering ? "Уже есть аккаунт? Войти" : "Создать аккаунт") {
                model.isRegistering.toggle()
                model.errorMessage = nil
            }
            .font(.footnote.weight(.medium))

            Spacer()
            Text("Подключение к официальному серверу vibecodeGram")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
